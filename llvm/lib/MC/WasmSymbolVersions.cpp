// SPDX-License-Identifier: MIT
// Copyright (c) 2026 linux-wasm-builder contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCSymbolWasm.h"
#include "llvm/MC/MCWasmStreamer.h"

using namespace llvm;

void MCWasmStreamer::emitSymbolVersions() {
  MCContext &Context = getContext();
  struct ResolvedVersion {
    const MCSymbolWasm *Original;
    MCSymbolWasm *Qualified;
    StringRef Base;
    bool Default;
    bool AddQualified;
    SMLoc Loc;
  };
  SmallVector<ResolvedVersion, 4> Resolved;
  // Resolve reference renames first, independently of directive order. A
  // default definition may share its assembler name with an explicit old
  // reference in this same translation unit.
  for (const SymbolVersion &Version : SymbolVersions) {
    const auto &Original = static_cast<const MCSymbolWasm &>(*Version.Original);
    StringRef Name = Version.Name;
    size_t At = Name.find('@');
    StringRef Base = Name.take_front(At);
    StringRef Suffix = Name.substr(At);
    bool Conditional = Suffix.starts_with("@@@");
    bool Default =
        Suffix.starts_with("@@") && (!Conditional || Original.isDefined());
    if (Original.isUndefined() && Default) {
      Context.reportError(Version.Loc, "default version symbol " + Name +
                                           " must be defined");
      continue;
    }
    if (!Original.isFunction() && !Original.isData()) {
      Context.reportError(Version.Loc,
                          "version aliases require function or data symbols");
      continue;
    }
    // Preserve explicit versions as ordinary Wasm linker names. Never bind an
    // old-version reference to the unqualified/default symbol.
    StringRef Tag = Suffix.drop_front(Conditional ? 3 : Default ? 2 : 1);
    auto *Qualified = static_cast<MCSymbolWasm *>(
        Context.getOrCreateSymbol(Twine(Base) + "@" + Tag));

    bool AddQualified = true;
    bool Rename = Original.isUndefined() || !Version.KeepOriginal ||
                  (!Default && Original.getName() == Base);
    if (Rename) {
      if (Original.hasLinkerName() &&
          Original.getLinkerName() != Qualified->getName()) {
        if (!Original.isDefined() || !Version.KeepOriginal) {
          Context.reportError(Version.Loc,
                              "multiple versions for " + Original.getName());
          continue;
        }
      } else {
        Original.setLinkerName(Qualified->getName());
        getAssembler().registerSymbol(Original);
        AddQualified = false;
      }
    }
    Resolved.push_back(
        {&Original, Qualified, Base, Default, AddQualified, Version.Loc});
  }

  for (const ResolvedVersion &Version : Resolved) {
    const MCSymbolWasm &Original = *Version.Original;
    auto AddAlias = [&](MCSymbolWasm *Alias) {
      StringRef AliasName = Alias->getName();
      if (Alias == &Original && Original.getLinkerName() == AliasName)
        return;
      // A C reference with this assembler name may already be bound to an
      // explicit old version. Do not overwrite that reference while adding
      // the independent default definition in the linker namespace.
      if (Alias->hasLinkerName() && Alias->getLinkerName() != AliasName) {
        Alias = static_cast<MCSymbolWasm *>(
            Context.createLinkerPrivateSymbol("symver"));
        Alias->setLinkerName(AliasName);
      }
      if (Alias->isDefined()) {
        Context.reportError(Version.Loc, "redefinition of versioned symbol " +
                                             Alias->getName());
        return;
      }
      if ((Alias->getType() &&
           *Alias->getType() !=
               Original.getType().value_or(wasm::WASM_SYMBOL_TYPE_DATA)) ||
          (Alias->getSignature() && Original.getSignature() &&
           *Alias->getSignature() != *Original.getSignature())) {
        Context.reportError(Version.Loc, "incompatible versioned symbol " +
                                             Alias->getName());
        return;
      }
      Alias->setType(Original.getType().value_or(wasm::WASM_SYMBOL_TYPE_DATA));
      Alias->setSignature(
          const_cast<wasm::WasmSignature *>(Original.getSignature()));
      Alias->setExternal(Original.isExternal());
      Alias->setWeak(Original.isWeak());
      Alias->setHidden(Original.isHidden());
      if (Original.isTLS())
        Alias->setTLS();
      getAssembler().registerSymbol(*Alias);
      emitAssignment(Alias, MCSymbolRefExpr::create(&Original, Context));
    };

    if (Version.AddQualified)
      AddAlias(Version.Qualified);
    if (Version.Default)
      AddAlias(
          static_cast<MCSymbolWasm *>(Context.getOrCreateSymbol(Version.Base)));
  }
}
