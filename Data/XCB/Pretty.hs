{-# LANGUAGE TypeSynonymInstances, FlexibleInstances #-}

-- |
-- Module    :  Data.XCB.Pretty
-- Copyright :  (c) Antoine Latter 2008
-- License   :  BSD3
--
-- Maintainer:  Antoine Latter <aslatter@gmail.com>
-- Stability :  provisional
-- Portability: portable - requires TypeSynonymInstances
--
-- Pretty-printers for the tyes declared in this package.
-- This does NOT ouput XML - it produces human-readable information
-- intended to aid in debugging.
module Data.XCB.Pretty where

import Data.XCB.Types

import Text.PrettyPrint.HughesPJ

import Data.Maybe

-- |Minimal complete definition:
--
-- One of 'pretty' or 'toDoc'.
class Pretty a where
    toDoc :: a -> Doc
    pretty :: a -> String

    pretty = show . toDoc
    toDoc = text . pretty

-- Builtin types

instance Pretty String where
    pretty = show

instance Pretty Int where
    pretty = show

instance Pretty a => Pretty (Maybe a) where
    toDoc Nothing = empty
    toDoc (Just a) = toDoc a

    pretty Nothing = ""
    pretty (Just a) = pretty a

-- Simple stuff

instance Pretty a => Pretty (GenXidUnionElem a) where
    toDoc (XidUnionElem t) = toDoc t

instance Pretty Binop where
    pretty Add  = "+"
    pretty Sub  = "-"
    pretty Mult = "*"
    pretty Div  = "/"
    pretty RShift = ">>"
    pretty And = "&"

instance Pretty Unop where
    pretty Compliment = "~"

instance Pretty EnumElem where
    toDoc (EnumElem name expr)
        = text name <> char ':' <+> toDoc expr

instance Pretty Type where
    toDoc (UnQualType name) = text name
    toDoc (QualType modifier name)
        = text modifier <> char '.' <> text name

-- More complex stuff

instance Pretty Expression where
    toDoc (Value n) = toDoc n
    toDoc (Bit n) = text "2^" <> toDoc n
    toDoc (FieldRef ref) = char '$' <> text ref
    toDoc (EnumRef parent child)
        = text parent <> char '.' <> text child
    toDoc (PopCount expr)
        = text "popcount" <> parens (toDoc expr)
    toDoc (SumOf ref)
        = text "sumof" <> (parens $ char '$' <> text ref)
    toDoc (Op binop exprL exprR)
        = parens $ hsep [toDoc exprL
                        ,toDoc binop
                        ,toDoc exprR
                        ]
    toDoc (Unop op expr)
        = parens $ toDoc op <> toDoc expr

instance Pretty a => Pretty (GenStructElem a) where
    toDoc (Pad n) = braces $ toDoc n <+> text "bytes"
    toDoc (List nm typ len enums)
        = text nm <+> text "::" <+> brackets (toDoc typ <+> toDoc enums) <+> toDoc len
    toDoc (SField nm typ enums mask) = hsep [text nm
                                            ,text "::"
                                            ,toDoc typ
                                            ,toDoc enums
                                            ,toDoc mask
                                            ]
    toDoc (ExprField nm typ expr)
        = parens (text nm <+> text "::" <+> toDoc typ)
          <+> toDoc expr
    toDoc (Switch name expr cases)
        = vcat
           [ text "switch" <> parens (toDoc expr) <> brackets (text name)
           , braces (vcat (map toDoc cases))
           ]
    toDoc (ValueParam typ mname mpad lname)
        = text "Valueparam" <+>
          text "::" <+>
          hsep (punctuate (char ',') details)

        where details
                  | isJust mpad =
                      [toDoc typ
                      ,text "mask padding:" <+> toDoc mpad
                      ,text mname
                      ,text lname
                      ]
                  | otherwise =
                      [toDoc typ
                      ,text mname
                      ,text lname
                      ]

instance Pretty a => Pretty (GenBitCase a) where
    toDoc (BitCase name expr fields)
        = vcat
           [ bitCaseHeader name expr
           , braces (vcat (map toDoc fields))
           ]

bitCaseHeader :: Maybe Name -> Expression -> Doc
bitCaseHeader Nothing expr =
    text "bitcase" <> parens (toDoc expr)
bitCaseHeader (Just name) expr =
    text "bitcase" <> parens (toDoc expr) <> brackets (text name)

instance Pretty a => Pretty (GenXDecl a) where
    toDoc (XStruct nm elems) =
        hang (text "Struct:" <+> text nm) 2 $ vcat $ map toDoc elems
    toDoc (XTypeDef nm typ) = hsep [text "TypeDef:"
                                    ,text nm
                                    ,text "as"
                                    ,toDoc typ
                                    ]
    toDoc (XEvent nm n elems (Just True)) =
        hang (text "Event:" <+> text nm <> char ',' <> toDoc n <+>
             parens (text "No sequence number")) 2 $
             vcat $ map toDoc elems
    toDoc (XEvent nm n elems _) =
        hang (text "Event:" <+> text nm <> char ',' <> toDoc n) 2 $
             vcat $ map toDoc elems
    toDoc (XRequest nm n elems mrep) = 
        (hang (text "Request:" <+> text nm <> char ',' <> toDoc n) 2 $
             vcat $ map toDoc elems)
         $$ case mrep of
             Nothing -> empty
             Just reply ->
                 hang (text "Reply:" <+> text nm <> char ',' <> toDoc n) 2 $
                      vcat $ map toDoc reply
    toDoc (XidType nm) = text "XID:" <+> text nm
    toDoc (XidUnion nm elems) = 
        hang (text "XID" <+> text "Union:" <+> text nm) 2 $
             vcat $ map toDoc elems
    toDoc (XEnum nm elems) =
        hang (text "Enum:" <+> text nm) 2 $ vcat $ map toDoc elems
    toDoc (XUnion nm elems) = 
        hang (text "Union:" <+> text nm) 2 $ vcat $ map toDoc elems
    toDoc (XImport nm) = text "Import:" <+> text nm
    toDoc (XError nm _n elems) =
        hang (text "Error:" <+> text nm) 2 $ vcat $ map toDoc elems

instance Pretty a => Pretty (GenXHeader a) where
    toDoc xhd = text (xheader_header xhd) $$
                (vcat $ map toDoc (xheader_decls xhd))
