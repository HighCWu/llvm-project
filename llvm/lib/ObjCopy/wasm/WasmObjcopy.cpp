//===- WasmObjcopy.cpp ----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/ObjCopy/wasm/WasmObjcopy.h"
#include "WasmObject.h"
#include "WasmReader.h"
#include "WasmWriter.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/BinaryFormat/Wasm.h"
#include "llvm/ObjCopy/CommonConfig.h"
#include "llvm/Object/Error.h"
#include "llvm/Support/DataExtractor.h"
#include "llvm/Support/Errc.h"
#include "llvm/Support/FileOutputBuffer.h"

namespace llvm {
namespace objcopy {
namespace wasm {

using namespace object;
using SectionPred = std::function<bool(const Section &Sec)>;

static bool isDebugSection(const Section &Sec) {
  return Sec.Name.starts_with(".debug") || Sec.Name.starts_with("reloc..debug");
}

static bool isLinkerSection(const Section &Sec) {
  return Sec.Name.starts_with("reloc.") || Sec.Name == "linking";
}

static bool isNameSection(const Section &Sec) { return Sec.Name == "name"; }

// Sections which are known to be "comments" or informational and do not affect
// program semantics.
static bool isCommentSection(const Section &Sec) {
  return Sec.Name == "producers";
}

static Error malformedSymbolTable() {
  return make_error<GenericBinaryError>(
      "malformed Wasm linking symbol table", object_error::parse_failed);
}

static Error skipULEB128(const DataExtractor &Extractor,
                         DataExtractor::Cursor &Cursor) {
  (void)Extractor.getULEB128(Cursor);
  if (!Cursor)
    return Cursor.takeError();
  return Error::success();
}

static Error skipString(const DataExtractor &Extractor,
                        DataExtractor::Cursor &Cursor) {
  uint64_t Length = Extractor.getULEB128(Cursor);
  if (!Cursor)
    return Cursor.takeError();
  Extractor.skip(Cursor, Length);
  if (!Cursor)
    return Cursor.takeError();
  return Error::success();
}

static Error skipSymbolPayload(const DataExtractor &Extractor,
                               DataExtractor::Cursor &Cursor, uint8_t Kind,
                               uint32_t Flags) {
  bool IsDefined = (Flags & llvm::wasm::WASM_SYMBOL_UNDEFINED) == 0;
  switch (Kind) {
  case llvm::wasm::WASM_SYMBOL_TYPE_FUNCTION:
  case llvm::wasm::WASM_SYMBOL_TYPE_GLOBAL:
  case llvm::wasm::WASM_SYMBOL_TYPE_TABLE:
  case llvm::wasm::WASM_SYMBOL_TYPE_TAG:
    if (Error E = skipULEB128(Extractor, Cursor))
      return E;
    if (IsDefined || (Flags & llvm::wasm::WASM_SYMBOL_EXPLICIT_NAME) != 0)
      return skipString(Extractor, Cursor);
    return Error::success();
  case llvm::wasm::WASM_SYMBOL_TYPE_DATA:
    if (Error E = skipString(Extractor, Cursor))
      return E;
    if (IsDefined) {
      if (Error E = skipULEB128(Extractor, Cursor)) // segment index
        return E;
      if (Error E = skipULEB128(Extractor, Cursor)) // memory64 offset
        return E;
      return skipULEB128(Extractor, Cursor); // memory64 size
    }
    return Error::success();
  case llvm::wasm::WASM_SYMBOL_TYPE_SECTION:
    return skipULEB128(Extractor, Cursor);
  default:
    return malformedSymbolTable();
  }
}

static Error collectWeakenedSymbols(const CommonConfig &Config,
                                    const DataExtractor &Extractor,
                                    uint64_t SectionOffset,
                                    ArrayRef<const WasmSymbol *> Symbols,
                                    SmallVectorImpl<uint64_t> &FlagOffsets) {
  DataExtractor::Cursor Cursor(0);
  uint64_t SymbolCount = Extractor.getULEB128(Cursor);
  if (!Cursor)
    return Cursor.takeError();
  if (SymbolCount != Symbols.size())
    return malformedSymbolTable();

  for (uint64_t I = 0; I < SymbolCount; ++I) {
    uint8_t Kind = Extractor.getU8(Cursor);
    if (!Cursor)
      return Cursor.takeError();
    uint64_t FlagsOffset = Cursor.tell();
    uint64_t Flags = Extractor.getULEB128(Cursor);
    if (!Cursor)
      return Cursor.takeError();

    const WasmSymbol &Symbol = *Symbols[I];
    if (Kind != Symbol.Info.Kind || Flags != Symbol.Info.Flags)
      return malformedSymbolTable();

    bool ShouldWeaken =
        Symbol.isDefined() && Symbol.isBindingGlobal() &&
        !Config.SymbolsToSkip.matches(Symbol.Info.Name) &&
        (Config.Weaken || Config.SymbolsToWeaken.matches(Symbol.Info.Name));
    if (ShouldWeaken)
      FlagOffsets.push_back(SectionOffset + FlagsOffset);

    if (Error E = skipSymbolPayload(Extractor, Cursor, Kind, Flags))
      return E;
  }

  if (Cursor.tell() != Extractor.size())
    return malformedSymbolTable();
  return Error::success();
}

static Error weakenSymbols(const CommonConfig &Config, const WasmObjectFile &In,
                           Object &Obj) {
  if (!Config.Weaken && Config.SymbolsToWeaken.empty())
    return Error::success();

  SmallVector<const WasmSymbol *, 0> Symbols;
  for (const SymbolRef &Sym : In.symbols())
    Symbols.push_back(&In.getWasmSymbol(Sym));

  Section *SymbolTableSection = nullptr;
  SmallVector<uint64_t, 8> FlagOffsets;
  for (Section &Sec : Obj.Sections) {
    if (Sec.SectionType != llvm::wasm::WASM_SEC_CUSTOM || Sec.Name != "linking")
      continue;

    DataExtractor Extractor(Sec.Contents, /*IsLittleEndian=*/true,
                            /*AddressSize=*/4);
    DataExtractor::Cursor Cursor(0);
    (void)Extractor.getULEB128(Cursor); // linking metadata version
    if (!Cursor)
      return Cursor.takeError();

    while (!Extractor.eof(Cursor)) {
      uint8_t SubsectionType = Extractor.getU8(Cursor);
      uint64_t SubsectionSize = Extractor.getULEB128(Cursor);
      if (!Cursor)
        return Cursor.takeError();

      uint64_t SubsectionOffset = Cursor.tell();
      if (SubsectionOffset > Sec.Contents.size() ||
          SubsectionSize > Sec.Contents.size() - SubsectionOffset)
        return malformedSymbolTable();

      if (SubsectionType == llvm::wasm::WASM_SYMBOL_TABLE) {
        if (SymbolTableSection)
          return malformedSymbolTable();
        SymbolTableSection = &Sec;
        DataExtractor SymtabExtractor(
            Sec.Contents.slice(SubsectionOffset, SubsectionSize),
            /*IsLittleEndian=*/true, /*AddressSize=*/4);
        if (Error E =
                collectWeakenedSymbols(Config, SymtabExtractor,
                                       SubsectionOffset, Symbols, FlagOffsets))
          return E;
      }

      Cursor.seek(SubsectionOffset + SubsectionSize);
    }
  }

  if (!SymbolTableSection || FlagOffsets.empty())
    return Error::success();

  SmallVector<uint8_t, 0> Contents(SymbolTableSection->Contents.begin(),
                                   SymbolTableSection->Contents.end());
  for (uint64_t Offset : FlagOffsets) {
    if (Offset >= Contents.size())
      return malformedSymbolTable();
    Contents[Offset] = static_cast<uint8_t>(
        (Contents[Offset] & ~uint8_t(llvm::wasm::WASM_SYMBOL_BINDING_MASK)) |
        llvm::wasm::WASM_SYMBOL_BINDING_WEAK);
  }

  StringRef ContentsRef(reinterpret_cast<const char *>(Contents.data()),
                        Contents.size());
  auto BufferCopy = MemoryBuffer::getMemBufferCopy(ContentsRef, "linking");
  Obj.replaceSectionContentsWithOwned(*SymbolTableSection,
                                      std::move(BufferCopy));
  return Error::success();
}

static Error dumpSectionToFile(StringRef SecName, StringRef Filename,
                               StringRef InputFilename, Object &Obj) {
  for (const Section &Sec : Obj.Sections) {
    if (Sec.Name == SecName) {
      ArrayRef<uint8_t> Contents = Sec.Contents;
      Expected<std::unique_ptr<FileOutputBuffer>> BufferOrErr =
          FileOutputBuffer::create(Filename, Contents.size());
      if (!BufferOrErr)
        return createFileError(Filename, BufferOrErr.takeError());
      std::unique_ptr<FileOutputBuffer> Buf = std::move(*BufferOrErr);
      llvm::copy(Contents, Buf->getBufferStart());
      if (Error E = Buf->commit())
        return createFileError(Filename, std::move(E));
      return Error::success();
    }
  }
  return createFileError(Filename, errc::invalid_argument,
                         "section '%s' not found", SecName.str().c_str());
}

static void removeSections(const CommonConfig &Config, Object &Obj) {
  SectionPred RemovePred = [](const Section &) { return false; };

  // Explicitly-requested sections.
  if (!Config.ToRemove.empty()) {
    RemovePred = [&Config](const Section &Sec) {
      return Config.ToRemove.matches(Sec.Name);
    };
  }

  if (Config.StripDebug) {
    RemovePred = [RemovePred](const Section &Sec) {
      return RemovePred(Sec) || isDebugSection(Sec);
    };
  }

  if (Config.StripAll) {
    RemovePred = [RemovePred](const Section &Sec) {
      return RemovePred(Sec) || isDebugSection(Sec) || isLinkerSection(Sec) ||
             isNameSection(Sec) || isCommentSection(Sec);
    };
  }

  if (Config.OnlyKeepDebug) {
    RemovePred = [&Config](const Section &Sec) {
      // Keep debug sections, unless explicitly requested to remove.
      // Remove everything else, including known sections.
      return Config.ToRemove.matches(Sec.Name) || !isDebugSection(Sec);
    };
  }

  if (!Config.OnlySection.empty()) {
    RemovePred = [&Config](const Section &Sec) {
      // Explicitly keep these sections regardless of previous removes.
      // Remove everything else, inluding known sections.
      return !Config.OnlySection.matches(Sec.Name);
    };
  }

  if (!Config.KeepSection.empty()) {
    RemovePred = [&Config, RemovePred](const Section &Sec) {
      // Explicitly keep these sections regardless of previous removes.
      if (Config.KeepSection.matches(Sec.Name))
        return false;
      // Otherwise defer to RemovePred.
      return RemovePred(Sec);
    };
  }

  Obj.removeSections(RemovePred);
}

static Error handleArgs(const CommonConfig &Config, const WasmObjectFile &In,
                        Object &Obj) {
  // Apply symbol and section operations supported by the Wasm object model.
  for (StringRef Flag : Config.DumpSection) {
    StringRef SecName;
    StringRef FileName;
    std::tie(SecName, FileName) = Flag.split("=");
    if (Error E =
            dumpSectionToFile(SecName, FileName, Config.InputFilename, Obj))
      return E;
  }

  if (Error E = weakenSymbols(Config, In, Obj))
    return E;

  removeSections(Config, Obj);

  for (const NewSectionInfo &NewSection : Config.AddSection) {
    Section Sec;
    Sec.SectionType = llvm::wasm::WASM_SEC_CUSTOM;
    Sec.Name = NewSection.SectionName;

    llvm::StringRef InputData =
        llvm::StringRef(NewSection.SectionData->getBufferStart(),
                        NewSection.SectionData->getBufferSize());
    std::unique_ptr<MemoryBuffer> BufferCopy = MemoryBuffer::getMemBufferCopy(
        InputData, NewSection.SectionData->getBufferIdentifier());
    Sec.Contents = ArrayRef<uint8_t>(
        reinterpret_cast<const uint8_t *>(BufferCopy->getBufferStart()),
        BufferCopy->getBufferSize());

    Obj.addSectionWithOwnedContents(Sec, std::move(BufferCopy));
  }

  return Error::success();
}

Error executeObjcopyOnBinary(const CommonConfig &Config, const WasmConfig &,
                             object::WasmObjectFile &In, raw_ostream &Out) {
  Reader TheReader(In);
  Expected<std::unique_ptr<Object>> ObjOrErr = TheReader.create();
  if (!ObjOrErr)
    return createFileError(Config.InputFilename, ObjOrErr.takeError());
  Object *Obj = ObjOrErr->get();
  assert(Obj && "Unable to deserialize Wasm object");
  if (Error E = handleArgs(Config, In, *Obj))
    return E;
  Writer TheWriter(*Obj, Out);
  if (Error E = TheWriter.write())
    return createFileError(Config.OutputFilename, std::move(E));
  return Error::success();
}

} // end namespace wasm
} // end namespace objcopy
} // end namespace llvm
