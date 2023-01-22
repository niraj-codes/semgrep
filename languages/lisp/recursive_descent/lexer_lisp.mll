{
(* Yoann Padioleau
 *
 * Copyright (C) 2010 Facebook
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
 *)
open Common

module Flag = Flag_parsing
open Parser_lisp

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)
(* shortcuts *)
let tok = Lexing.lexeme
let tokinfo = Parse_info.tokinfo
let error = Parse_info.lexical_error

}

(*****************************************************************************)
let letter = ['a'-'z''A'-'Z']
let digit = ['0'-'9']

let symbol =
  ['-' '+' '=' '~'  '.'  ',' '/' ':' '<' '>' '*' ';' '#'
   '_'  '?' '^' '|' '!' '&'
   '%' '@' '{' '}' '$'
  ]
(*
'\\'
'@'
'"'
'`'
*)

(*****************************************************************************)
rule token = parse

  (* ----------------------------------------------------------------------- *)
  (* spacing/comments *)
  (* ----------------------------------------------------------------------- *)
  | ";" [^'\n' '\r']* {
      TComment(tokinfo lexbuf)
    }
  | [' ''\t']+ { TCommentSpace (tokinfo lexbuf) }
  | "\n" { TCommentNewline (tokinfo lexbuf) }
  | "" { TCommentNewline (tokinfo lexbuf) }

  (* ----------------------------------------------------------------------- *)
  (* Symbols *)
  (* ----------------------------------------------------------------------- *)

  | '(' { TOParen (tokinfo lexbuf) } | ')' { TCParen (tokinfo lexbuf) }
  | "[" { TOBracket(tokinfo lexbuf) }  | "]" { TCBracket(tokinfo lexbuf) }

  | '\'' { TQuote (tokinfo lexbuf) }
  (* special rule for symbols e.g. 'foo ? or because '(foo) is also
   * valid just let the parser differentiate those different quoted
   * things ?
   *)
  | '`'  { TBackQuote (tokinfo lexbuf) }
  | ','  { TComma (tokinfo lexbuf) }
  | ",@"  { TAt (tokinfo lexbuf) }

  (* ----------------------------------------------------------------------- *)
  (* Strings *)
  (* ----------------------------------------------------------------------- *)
  | '"' {
      (* opti: use Buffer because some autogenerated files can
       * contains huge strings
       *)
      let info = tokinfo lexbuf in
      let buf = Buffer.create 100 in
      string buf lexbuf;
      let s = Buffer.contents buf in
      TString (s, info |> Parse_info.tok_add_s (s ^ "\""))
    }

   (* maybe elisp specific *)
  | '\\' _ {
      TString (tok lexbuf, tokinfo lexbuf)
  }
  | "?\\" _ {
      TString (tok lexbuf, tokinfo lexbuf)
  }
  | '?' _ {
      TString (tok lexbuf, tokinfo lexbuf)
  }

  (* unicode ... *)
  | "?━" {
      TString (tok lexbuf, tokinfo lexbuf)
  }
  (* ----------------------------------------------------------------------- *)
  (* Keywords and ident *)
  (* ----------------------------------------------------------------------- *)
  | (letter | symbol) (letter | digit | symbol)* {
      TIdent (tok lexbuf, tokinfo lexbuf)
    }


  (* ----------------------------------------------------------------------- *)
  (* Constant *)
  (* ----------------------------------------------------------------------- *)

  | digit+ {
      TNumber(tok lexbuf, tokinfo lexbuf)
    }

  (* ----------------------------------------------------------------------- *)
  | eof { EOF (tokinfo lexbuf |> Parse_info.rewrap_str "") }
  | _ {
        if !Flag.verbose_lexing
        then pr2_once ("LEXER:unrecognised symbol, in token rule:"^tok lexbuf);
        TUnknown (tokinfo lexbuf)
    }

(*****************************************************************************)

and string buf = parse
  | '"'           { Buffer.add_string buf "" }
  (* opti: *)
  | [^ '"' '\\']+ {
      Buffer.add_string buf (tok lexbuf);
      string buf lexbuf
    }

  | ("\\" (_ as v)) as x {
      (* todo: check char ? *)
      (match v with
      | _ -> ()
      );
      Buffer.add_string buf x;
      string buf lexbuf
    }
  | eof {
      pr2 "LEXER: WIERD end of file in double quoted string";
    }