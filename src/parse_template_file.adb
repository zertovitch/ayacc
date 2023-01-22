-- $Header: /dc/uc/self/arcadia/ayacc/src/RCS/parse_template_file.a,v 1.1 1993/01/15 23:39:54 self Exp self $

-- Copyright (c) 1990 Regents of the University of California.
-- All rights reserved.
--
--    The primary authors of ayacc were David Taback and Deepak Tolani.
--    Enhancements were made by Ronald J. Schmalz.
--
--    Send requests for ayacc information to ayacc-info@ics.uci.edu
--    Send bug reports for ayacc to ayacc-bugs@ics.uci.edu
--
-- Redistribution and use in source and binary forms are permitted
-- provided that the above copyright notice and this paragraph are
-- duplicated in all such forms and that any documentation,
-- advertising materials, and other materials related to such
-- distribution and use acknowledge that the software was developed
-- by the University of California, Irvine.  The name of the
-- University may not be used to endorse or promote products derived
-- from this software without specific prior written permission.
-- THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
-- IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
-- WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

-- Module       : parse_template_file.ada
-- Component of : ayacc
-- Version      : 1.2
-- Date         : 11/21/86  12:33:32
-- SCCS File    : disk21~/rschm/hasee/sccs/ayacc/sccs/sxparse_template_file.ada

--**
--  6-Aug-2008 GdM: Added "at line ..." to Syntax Error
--        2006 GdM: Added ref to YY_Sizes package (no more hardcoding of sizes)

--**

-- $Header: /dc/uc/self/arcadia/ayacc/src/RCS/parse_template_file.a,v 1.1 1993/01/15 23:39:54 self Exp self $
-- $Log: parse_template_file.a,v $
-- Revision 1.1  1993/01/15  23:39:54  self
-- Initial revision
--
--Revision 1.1  88/08/08  14:20:23  arcadia
--Initial revision
--
-- Revision 0.1  86/04/01  15:09:47  ada
--  This version fixes some minor bugs with empty grammars
--  and $$ expansion. It also uses vads5.1b enhancements
--  such as pragma inline.
--
--
-- Revision 0.0  86/02/19  18:40:09  ada
--
-- These files comprise the initial version of Ayacc
-- designed and implemented by David Taback and Deepak Tolani.
-- Ayacc has been compiled and tested under the Verdix Ada compiler
-- version 4.06 on a vax 11/750 running Unix 4.2BSD.
--

with Ada.Strings.Fixed;

with Options;
with Ayacc_File_Names;
with String_Pkg; use String_Pkg;
pragma Elaborate (String_Pkg);
package body Parse_Template_File is

   use Ada.Text_IO;

   -- SCCS_ID : constant String := "@(#) parse_template_file.ada, Version 1.2";
   -- Rcs_ID : constant String := "$Header: /dc/uc/self/arcadia/ayacc/src/RCS/parse_template_file.a,v 1.1 1993/01/15 23:39:54 self Exp self $";

   File_Pointer : Natural := 0;

   type File_Data is array (Positive range <>) of String_Type;
   type File_Access is access File_Data;

   Yyparse_Template_File : File_Access; -- access File_Data;

   procedure Write_Line (Outfile : in File_Type;
                         Line    : in String) is
      Start : Natural := Line'First;
      Pos   : Natural;
   begin
      while Start <= Line'Last loop
         Pos := Ada.Strings.Fixed.Index (Line, "${", Start);
         if Pos = 0 then
            Put_Line (Outfile, Line (Start .. Line'Last));
            exit;
         elsif Line (Pos .. Pos + 7) = "${YYLEX}" then
            declare
               Name : constant String := Ayacc_File_Names.Lex_Function_Name;
            begin
               Put (Outfile, Line (Start .. Pos - 1));
               if Name'Length > 0 then
                  Put (Outfile, Name);
               else
                  Put (Outfile, "YYLex");
               end if;
               Start := Pos + 8;

            end;
         elsif Line (Pos .. Pos + 9) = "${YYPARSE}" then
            Put (Outfile, Line (Start .. Pos - 1));
            Put (Outfile, Ayacc_File_Names.Get_Parse_Name);
            Start := Pos + 10;

         elsif Line (Pos .. Pos + 6) = "${NAME}" then
            Put (Outfile, Line (Start .. Pos - 1));
            Put (Outfile, Options.Ayacc_Stack_Size);
            Start := Pos + 7;

         elsif Line (Pos .. Pos + 14) = "${YYPARSEPARAM}" then
            Put (Outfile, Line (Start .. Pos - 1));
            Put (Outfile, Ayacc_File_Names.get_Parse_Params);
            Start := Pos + 15;

         elsif Line (Pos .. Pos + 13) = "${YYSTACKSIZE}" then
            begin
               Put (Outfile, Line (Start .. Pos - 1));
               Put (Outfile, Options.Ayacc_Stack_Size);
               Start := Pos + 14;
            end;
         else
            Put_Line (Outfile, Line (Start .. Line'Last));
            exit;
         end if;
         if Start > Line'Last then
            New_Line (Outfile);
         end if;
      end loop;
   end Write_Line;

   procedure Template_Writer (Outfile  : in File_Type) is

      type Section_Type is (S_COMMON,
                            S_IF_DEBUG,
                            S_IF_ERROR,
                            S_IF_PRIVATE,
                            S_IF_YYERROK,
                            S_IF_YYCLEARIN);
      Current    : Section_Type := S_COMMON;
      Is_Visible : Boolean := True;
      Invert     : Boolean := False;
      Continue   : Boolean := True;
   begin
      while Continue and then Has_Line loop
         declare
            Line : constant String := Get_Line;
         begin
            if Line'Length = 0 then
               if Is_Visible then
                  New_Line (Outfile);
               end if;
            elsif Line (Line'First) = '%' then
               if Line = "%if debug" then
                  Current := S_IF_DEBUG;
               elsif Line = "%if error" then
                  Current := S_IF_ERROR;
               elsif Line = "%if private" then
                  Current := S_IF_PRIVATE;
               elsif Line = "%if yyerrok" then
                  Current := S_IF_YYERROK;
               elsif Line = "%if yyclearin" then
                  Current := S_IF_YYCLEARIN;
               elsif Line = "%end" then
                  Current := S_COMMON;
                  Invert := False;
               elsif Line = "%else" then
                  Invert := True;
               elsif Line'Length > 3 and then Line (Line'First + 1) = '%' then
                  Continue := False;
                  return;
               else
                  --  Very crude error report when the template % line is invalid.
                  --  This could happen only during development when templates
                  --  are modified.
                  raise Program_Error with "Invalid template '%' rule: " & Line;
               end if;
               Is_Visible := (Current = S_COMMON)
                 or else (Current = S_IF_DEBUG and then Options.Debug)
                 or else (Current = S_IF_PRIVATE and then Options.Package_Private)
                 or else (Current = S_IF_YYERROK and then not Options.Skip_Yyerrok)
                 or else (Current = S_IF_YYCLEARIN and then not Options.Skip_Yyclearin)
                 or else (Current = S_IF_ERROR and then Options.Error_Recovery_Extension);
               if Invert then
                  Is_Visible := not Is_Visible;
               end if;

            elsif Is_Visible then
               Write_Line (Outfile, Line);
            end if;
         end;
      end loop;
   end Template_Writer;

   procedure Write_Template (Outfile  : in File_Type;
                             Lines    : in Content_Array;
                             Position : in out Positive) is
      function Has_Line return Boolean is
      begin
         return Position <= Lines'Last;
      end Has_Line;

      function Get_Line return String is
      begin
         Position := Position + 1;
         return Lines (Position - 1).all;
      end Get_Line;

      procedure Write is new Template_Writer (Has_Line, Get_Line);

   begin
      Write (Outfile);
    end Write_Template;

   procedure Initialize is
   begin
      Yyparse_Template_File :=
        new File_Data'
          ( -- Start of File Contents
      Create
             ("--  Warning: This file is automatically generated by AYACC."),
           Create
             ("--           It is useless to modify it. Change the "".Y"" & "".L"" files instead."),
           Create (""),
--       Create ("with YY_Sizes;"),
--       Create ("-- ^ 14-Jan-2006 (GdM): configurable sizes instead of hard-coded"),
--       Create ("--   ones in AYACC's output"),
      Create (""), Create ("   procedure YYParse is"),
           Create (""),
           Create
             ("      --  Rename User Defined Packages to Internal Names."),
           Create ("%%"), Create (""),
           Create
             ("      use yy_tokens, yy_goto_tables, yy_shift_reduce_tables;"),
           Create ("-- YYERROK :"), Create (""),
           Create ("      procedure yyerrok;"), Create ("-- END OF YYERROK."),
           Create ("-- YYCLEARIN :"), Create ("      procedure yyclearin;"),
           Create ("-- END OF YYCLEARIN."),
           Create ("      procedure handle_error;"),
           Create ("-- UMASS CODES :"), Create (""),
           Create ("      --   One of the extension of ayacc. Used for"),
           Create ("      --   error recovery and error reporting."),
           Create (""), Create ("      package yyparser_input is"),
           Create ("         --"), Create ("         --  TITLE"),
           Create ("         --   yyparser input."), Create ("         --"),
           Create ("         -- OVERVIEW"),
           Create
             ("         --   In Ayacc, parser get the input directly from lexical scanner."),
           Create
             ("         --   In the extension, we have more power in error recovery which will"),
           Create
             ("         --   try to replace, delete or insert a token into the input"),
           Create
             ("         --   stream. Since general lexical scanner does not support"),
           Create
             ("         --   replace, delete or insert a token, we must maintain our"),
           Create
             ("         --   own input stream to support these functions. It is the"),
           Create
             ("         --   purpose that we introduce yyparser_input. So parser no"),
           Create
             ("         --   longer interacts with lexical scanner, instead, parser"),
           Create
             ("         --   will get the input from yyparser_input. Yyparser_Input"),
           Create
             ("         --   get the input from lexical scanner and supports"),
           Create ("         --   replacing, deleting and inserting tokens."),
           Create ("         --"), Create (""),
           Create ("         type string_ptr is access string;"), Create (""),
           Create ("         type tokenbox is record"),
           Create ("          --"), Create ("          --  OVERVIEW"),
           Create
             ("          --    Tokenbox is the type of the element of the input"),
           Create
             ("          --    stream maintained in yyparser_input. It contains"),
           Create
             ("          --    the value of the token, the line on which the token"),
           Create
             ("          --    resides, the line number on which the token resides."),
           Create
             ("          --    It also contains the begin and end column of the token."),
           Create ("            token         : yy_tokens.Token;"),
           Create ("            lval          : YYSType;"),
           Create ("            line          : string_ptr;"),
           Create ("            line_number   : Natural := 1;"),
           Create ("            token_start   : Natural := 1;"),
           Create ("            token_end     : Natural := 1;"),
           Create ("         end record;"), Create (""),
           Create ("         type boxed_token is access tokenbox;"),
           Create (""),
           Create ("         procedure unget(tok : in boxed_token);"),
           Create ("         --  push a token back into input stream."),
           Create (""), Create ("         function get return boxed_token;"),
           Create ("         --  get a token from input stream"), Create (""),
           Create ("         procedure reset_peek;"),
           Create ("         function peek return boxed_token;"),
           Create
             ("         --  During error recovery, we will lookahead to see the"),
           Create
             ("         --  affect of the error recovery. The lookahead does not"),
           Create
             ("         --  means that we actually accept the input, instead, it"),
           Create
             ("         --  only means that we peek the future input. It is the"),
           Create
             ("         --  purpose of function peek and it is also the difference"),
           Create
             ("         --  between peek and get. We maintain a counter indicating"),
           Create
             ("         --  how many token we have peeked and reset_peek will"),
           Create ("         --  reset that counter."), Create (""),
           Create
             ("         function tbox (token : yy_tokens.Token ) return boxed_token;"),
           Create
             ("         --  Given the token got from the lexical scanner, tbox"),
           Create
             ("         --  collect other information, such as, line, line number etc."),
           Create ("         --  to construct a boxed_token."), Create (""),
           Create ("         input_token    : yyparser_input.boxed_token;"),
           Create ("         previous_token : yyparser_input.boxed_token;"),
           Create
             ("         --  The current and previous token processed by parser."),
           Create (""), Create ("      end yyparser_input;"), Create (""),
           Create ("      package yyerror_recovery is"),
           Create ("         --"), Create ("         -- TITLE"),
           Create ("         --"), Create ("         --   Yyerror_Recovery."),
           Create ("         --"), Create ("         -- OVERVIEW"),
           Create
             ("         --   This package contains all of errro recovery staff,"),
           Create ("         --   in addition to those of Ayacc."),
           Create (""), Create ("         previous_action : Integer;"),
           Create
             ("         -- This variable is used to save the previous action the parser made."),
           Create (""),
           Create ("         previous_error_flag : Natural := 0;"),
           Create
             ("         -- This variable is used to save the previous error flag."),
           Create (""), Create ("         valuing : Boolean := True;"),
           Create
             ("         -- Indicates whether to perform semantic actions. If exception"),
           Create
             ("         -- is raised during semantic action after error recovery, we"),
           Create
             ("         -- set valuing to False which causes no semantic actions to"),
           Create ("         -- be invoked any more."), Create (""),
           Create
             ("         procedure flag_token ( error : in Boolean := True );"),
           Create
             ("         --  This procedure will point out the position of the"),
           Create ("         --  current token."), Create (""),
           Create ("         procedure finale;"),
           Create
             ("         -- This procedure prepares the final report for error report."),
           Create (""), Create ("         procedure try_recovery;"),
           Create ("         -- It is the main procedure for error recovery."),
           Create (""), Create ("         line_number : Integer := 0;"),
           Create
             ("         -- Indicates the last line having been outputed to the error file."),
           Create (""), Create ("         procedure put_new_line;"),
           Create
             ("         -- This procedure outputs the whole line on which input_token"),
           Create
             ("         -- resides along with line number to the file for error reporting."),
           Create ("      end yyerror_recovery;"), Create (""),
           Create ("      use yyerror_recovery;"), Create (""),
           Create ("      package user_defined_errors is"),
           Create ("         --"), Create ("         --  TITLE"),
           Create ("         --    User Defined Errors."),
           Create ("         --"), Create ("         --  OVERVIEW"),
           Create
             ("         --    This package is used to facilite the error reporting."),
           Create (""),
           Create ("         procedure parser_error(Message : in String );"),
           Create ("         procedure parser_warning(Message : in String );"),
           Create (""), Create ("      end user_defined_errors;"), Create (""),
           Create ("-- END OF UMASS CODES."), Create (""),
           Create ("      subtype goto_row is yy_goto_tables.Row;"),
           Create ("      subtype reduce_row is yy_shift_reduce_tables.Row;"),
           Create (""), Create ("      package yy is"), Create (""),
           Create ("         --  the size of the value and state stacks"),
           Create
             ("         --  Affects error 'Stack size exceeded on state_stack'"),
           Create
             ("         stack_size : constant Natural :=" &
              Options.Ayacc_Stack_Size & ";"),

      --  One program with a approx 400 lines procedure containing
      --  mainly "... else if ..."'s, needed  stack_size to be between
      --  350 and 400.  17Nov2002: [GACC]. The v. similar source code in
      --  Newp2Ada's newp2ada/AFLEXNAT/PARSER.ADB, is ignored.

           Create (""),
           Create ("         --  subtype rule         is Natural;"),
           Create ("         subtype parse_state is Natural;"),
           Create ("         --  subtype nonterminal  is Integer;"),
           Create (""), Create ("         --  encryption constants"),
           Create ("         default           : constant := -1;"),
           Create ("         first_shift_entry : constant := 0;"),
           Create ("         accept_code       : constant := -3001;"),
           Create ("         error_code        : constant := -3000;"),
           Create (""), Create ("         --  stack data used by the parser"),
           Create ("         tos                : Natural := 0;"),
           Create
             ("         value_stack        : array (0 .. stack_size) of yy_tokens.YYSType;"),
           Create
             ("         state_stack        : array (0 .. stack_size) of parse_state;"),
           Create (""),
           Create
             ("         --  current input symbol and action the parser is on"),
           Create ("         action             : Integer;"),
           Create ("         rule_id            : Rule;"),
           Create ("         input_symbol       : yy_tokens.Token := ERROR;"),
           Create (""), Create ("         --  error recovery flag"),
           Create ("         error_flag : Natural := 0;"),
           Create
             ("         --  indicates  3 - (number of valid shifts after an error occurs)"),
           Create (""), Create ("         look_ahead : Boolean := True;"),
           Create ("         index      : reduce_row;"), Create (""),
           Create ("         --  Is Debugging option on or off"),
           Create ("%%"), Create (""), Create ("      end yy;"), Create (""),
           Create
             ("      procedure shift_debug (state_id : yy.parse_state; lexeme : yy_tokens.Token);"),
           Create
             ("      procedure reduce_debug (rule_id : Rule; state_id : yy.parse_state);"),
           Create (""), Create ("      function goto_state"),
           Create ("         (state : yy.parse_state;"),
           Create ("          sym   : Nonterminal) return yy.parse_state;"),
           Create (""), Create ("      function parse_action"),
           Create ("         (state : yy.parse_state;"),
           Create ("          t     : yy_tokens.Token) return Integer;"),
           Create (""),
           Create ("      pragma Inline (goto_state, parse_action);"),
           Create (""),
           Create ("      function goto_state (state : yy.parse_state;"),
           Create
             ("                           sym   : Nonterminal) return yy.parse_state is"),
           Create ("         index : goto_row;"), Create ("      begin"),
           Create ("         index := Goto_Offset (state);"),
           Create ("         while Goto_Matrix (index).Nonterm /= sym loop"),
           Create ("            index := index + 1;"),
           Create ("         end loop;"),
           Create ("         return Integer (Goto_Matrix (index).Newstate);"),
           Create ("      end goto_state;"), Create (""), Create (""),
           Create ("      function parse_action (state : yy.parse_state;"),
           Create
             ("                             t     : yy_tokens.Token) return Integer is"),
           Create ("         index   : reduce_row;"),
           Create ("         tok_pos : Integer;"),
           Create ("         default : constant Integer := -1;"),
           Create ("      begin"),
           Create ("         tok_pos := yy_tokens.Token'Pos (t);"),
           Create ("         index   := Shift_Reduce_Offset (state);"),
           Create
             ("         while Integer (Shift_Reduce_Matrix (index).T) /= tok_pos"),
           Create
             ("           and then Integer (Shift_Reduce_Matrix (index).T) /= default"),
           Create ("         loop"),
           Create ("            index := index + 1;"),
           Create ("         end loop;"),
           Create
             ("         return Integer (Shift_Reduce_Matrix (index).Act);"),
           Create ("      end parse_action;"), Create (""),
           Create ("      --  error recovery stuff"), Create (""),
           Create ("      procedure handle_error is"),
           Create ("         temp_action : Integer;"), Create ("      begin"),
           Create (""),
           Create
             ("         if yy.error_flag = 3 then --  no shift yet, clobber input."),
           Create ("            if yy.debug then"),
           Create
             ("               Text_IO.Put_Line (""  -- Ayacc.YYParse: Error Recovery Clobbers """),
           Create
             ("                                 & yy_tokens.Token'Image (yy.input_symbol));"),
           Create ("-- UMASS CODES :"),
           Create
             ("               yy_error_report.Put_Line (""Ayacc.YYParse: Error Recovery Clobbers """),
           Create
             ("                                         & yy_tokens.Token'Image (yy.input_symbol));"),
           Create ("-- END OF UMASS CODES."), Create ("            end if;"),
           Create
             ("            if yy.input_symbol = yy_tokens.END_OF_INPUT then  -- don't discard,"),
           Create ("               if yy.debug then"),
           Create
             ("                  Text_IO.Put_Line (""  -- Ayacc.YYParse: Can't discard END_OF_INPUT, quiting..."");"),
           Create ("-- UMASS CODES :"),
           Create
             ("                  yy_error_report.Put_Line (""Ayacc.YYParse: Can't discard END_OF_INPUT, quiting..."");"),
           Create ("-- END OF UMASS CODES."),
           Create ("               end if;"), Create ("-- UMASS CODES :"),
           Create ("               yyerror_recovery.finale;"),
           Create ("-- END OF UMASS CODES."),
           Create ("               raise yy_tokens.Syntax_Error;"),
           Create ("            end if;"), Create (""),
           Create ("            yy.look_ahead := True;   --  get next token"),
           Create
             ("            return;                  --  and try again..."),
           Create ("         end if;"), Create (""),
           Create ("         if yy.error_flag = 0 then --  brand new error"),
           Create ("            yyerror (""Syntax Error"");"),
           Create ("-- UMASS CODES :"),
           Create
             ("            yy_error_report.Put_Line ( ""Skipping..."" );"),
           Create ("            yy_error_report.Put_Line ( """" );"),
           Create ("-- END OF UMASS CODES."), Create ("         end if;"),
           Create (""), Create ("         yy.error_flag := 3;"), Create (""),
           Create
             ("         --  find state on stack where error is a valid shift --"),
           Create (""), Create ("         if yy.debug then"),
           Create
             ("            Text_IO.Put_Line (""  -- Ayacc.YYParse: Looking for state with error as valid shift"");"),
           Create ("-- UMASS CODES :"),
           Create
             ("            yy_error_report.Put_Line(""Ayacc.YYParse: Looking for state with error as valid shift"");"),
           Create ("-- END OF UMASS CODES."), Create ("         end if;"),
           Create (""), Create ("         loop"),
           Create ("            if yy.debug then"),
           Create
             ("               Text_IO.Put_Line (""  -- Ayacc.YYParse: Examining State """),
           Create
             ("                                 & yy.parse_state'Image (yy.state_stack (yy.tos)));"),
           Create ("-- UMASS CODES :"),
           Create
             ("               yy_error_report.Put_Line (""Ayacc.YYParse: Examining State """),
           Create
             ("                                         & yy.parse_state'Image (yy.state_stack (yy.tos)));"),
           Create ("-- END OF UMASS CODES."), Create ("            end if;"),
           Create
             ("            temp_action := parse_action (yy.state_stack (yy.tos), ERROR);"),
           Create (""),
           Create ("            if temp_action >= yy.first_shift_entry then"),
           Create ("               if yy.tos = yy.stack_size then"),
           Create
             ("                  Text_IO.Put_Line (""  -- Ayacc.YYParse: Stack size exceeded on state_stack"");"),
           Create ("-- UMASS CODES :"),
           Create
             ("                  yy_error_report.Put_Line (""Ayacc.YYParse: Stack size exceeded on state_stack"");"),
           Create ("                  yyerror_recovery.finale;"),
           Create ("-- END OF UMASS CODES."),
           Create ("                  raise yy_tokens.Syntax_Error;"),
           Create ("               end if;"),
           Create ("               yy.tos                  := yy.tos + 1;"),
           Create ("               yy.state_stack (yy.tos) := temp_action;"),
           Create ("               exit;"), Create ("            end if;"),
           Create (""), Create ("            if yy.tos /= 0 then"),
           Create ("               yy.tos := yy.tos - 1;"),
           Create ("            end if;"), Create (""),
           Create ("            if yy.tos = 0 then"),
           Create ("               if yy.debug then"),
           Create ("                  Text_IO.Put_Line"),
           Create
             ("                     (""  -- Ayacc.YYParse: Error recovery popped entire stack, aborting..."");"),
           Create ("-- UMASS CODES :"),
           Create ("                  yy_error_report.Put_Line"),
           Create
             ("                     (""Ayacc.YYParse: Error recovery popped entire stack, aborting..."");"),
           Create ("-- END OF UMASS CODES."),
           Create ("               end if;"), Create ("-- UMASS CODES :"),
           Create ("               yyerror_recovery.finale;"),
           Create ("-- END OF UMASS CODES."),
           Create ("               raise yy_tokens.Syntax_Error;"),
           Create ("            end if;"), Create ("         end loop;"),
           Create (""), Create ("         if yy.debug then"),
           Create
             ("            Text_IO.Put_Line (""  -- Ayacc.YYParse: Shifted error token in state """),
           Create
             ("                              & yy.parse_state'Image (yy.state_stack (yy.tos)));"),
           Create ("-- UMASS CODES :"),
           Create
             ("            yy_error_report.Put_Line (""Ayacc.YYParse: Shifted error token in state "" &"),
           Create
             ("                                      yy.parse_state'Image (yy.state_stack (yy.tos)));"),
           Create ("-- END OF UMASS CODES."), Create ("         end if;"),
           Create (""), Create ("      end handle_error;"), Create (""),
           Create
             ("      --  print debugging information for a shift operation"),
           Create
             ("      procedure shift_debug (state_id : yy.parse_state; lexeme : yy_tokens.Token) is"),
           Create ("      begin"),
           Create
             ("         Text_IO.Put_Line (""  -- Ayacc.YYParse: Shift """),
           Create
             ("                           & yy.parse_state'Image (state_id) & "" on input symbol """),
           Create
             ("                           & yy_tokens.Token'Image (lexeme));"),
           Create ("-- UMASS CODES :"),
           Create
             ("         yy_error_report.Put_Line (""Ayacc.YYParse: Shift ""& yy.parse_state'Image (state_id)&"" on input symbol ""&"),
           Create
             ("                                   yy_tokens.Token'Image (lexeme) );"),
           Create ("-- END OF UMASS CODES."),
           Create ("      end shift_debug;"), Create (""),
           Create
             ("      --  print debugging information for a reduce operation"),
           Create
             ("      procedure reduce_debug (rule_id : Rule; state_id : yy.parse_state) is"),
           Create ("      begin"),
           Create
             ("         Text_IO.Put_Line (""  -- Ayacc.YYParse: Reduce by rule """),
           Create
             ("                           & Rule'Image (rule_id) & "" goto state """),
           Create
             ("                           & yy.parse_state'Image (state_id));"),
           Create ("-- UMASS CODES :"),
           Create
             ("         yy_error_report.Put_Line (""Ayacc.YYParse: Reduce by rule "" & Rule'Image (rule_id) & "" goto state ""&"),
           Create
             ("                                   yy.parse_state'Image (state_id));"),
           Create ("-- END OF UMASS CODES."),
           Create ("      end reduce_debug;"), Create (""),
           Create ("-- YYERROK :"),
           Create
             ("      --  make the parser believe that 3 valid shifts have occured."),
           Create ("      --  used for error recovery."),
           Create ("      procedure yyerrok is"), Create ("      begin"),
           Create ("         yy.error_flag := 0;"),
           Create ("      end yyerrok;"), Create (""),
           Create ("-- END OF YYERROK."), Create ("-- YYCLEARIN :"),
           Create
             ("      --  called to clear input symbol that caused an error."),
           Create ("      procedure yyclearin is"), Create ("      begin"),
           Create ("         --  yy.input_symbol := YYLex;"),
           Create ("         yy.look_ahead := True;"),
           Create ("      end yyclearin;"), Create (""),
           Create ("-- END OF YYCLEARIN."), Create ("-- UMASS CODES :"),
           Create
             ("   --   Bodies of yyparser_input, yyerror_recovery, user_define_errors."),
           Create (""), Create ("package body yyparser_input is"),
           Create ("   pragma Style_Checks (""-mrlut"");"), Create (""),
           Create ("   input_stream_size : constant Integer := 10;"),
           Create ("   --  Input_stream_size indicates how many tokens can"),
           Create ("   --  be hold in input stream."), Create (""),
           Create
             ("   input_stream : array (0 .. input_stream_size - 1) of boxed_token;"),
           Create (""),
           Create
             ("   index : Integer := 0;           --  Indicates the position of the next"),
           Create
             ("                                   --  buffered token in the input stream."),
           Create
             ("   peek_count : Integer := 0;      --  # of tokens seen by peeking in the input stream."),
           Create
             ("   buffered : Integer := 0;        --  # of buffered tokens in the input stream."),
           Create (""),
           Create
             ("   function tbox(token : yy_tokens.Token) return boxed_token is"),
           Create ("     boxed : boxed_token;"),
           Create ("     line : string ( 1 .. 1024 );"),
           Create ("     line_length : Integer;"), Create ("   begin"),
           Create ("      boxed := new tokenbox;"),
           Create ("      boxed.token := token;"),
           Create ("      boxed.lval := YYLVal;"),
           Create ("      boxed.line_number := yy_line_number;"),
           Create ("      yy_get_token_line (line, line_length);"),
           Create ("      boxed.line := new String (1 .. line_length);"),
           Create
             ("      boxed.line (1 .. line_length ) := line (1 .. line_length);"),
           Create ("      boxed.token_start := yy_begin_column;"),
           Create ("      boxed.token_end := yy_end_column;"),
           Create ("      return boxed;"), Create ("   end tbox;"),
           Create (""), Create ("   function get return boxed_token is"),
           Create ("      t : boxed_token;"), Create ("   begin"),
           Create ("      if buffered = 0 then"),
           Create ("         --  No token is buffered in the input stream"),
           Create
             ("         --  so we get input from lexical scanner and return."),
           Create ("         return tbox (YYLex);"), Create ("      else"),
           Create ("         --  return the next buffered token. And remove"),
           Create ("         --  it from input stream."),
           Create ("         t := input_stream (index);"),
           Create ("         yylval := t.lval;"),
           Create ("         --  Increase index and decrease buffered has"),
           Create ("         --  the affect of removing the returned token"),
           Create ("         --  from input stream."),
           Create ("         index := (index + 1) mod input_stream_size;"),
           Create ("         buffered := buffered - 1;"),
           Create ("         if peek_count > 0 then"),
           Create ("            --  Previously we were peeking the tokens"),
           Create
             ("            --  from index - 1 to index - 1 + peek_count."),
           Create ("            --  But now token at index - 1 is returned"),
           Create ("            --  and remove, so this token is no longer"),
           Create ("            --  one of the token being peek. So we must"),
           Create ("            --  decrease the peek_count. If peek_count"),
           Create ("            --  is 0, we remains peeking 0 token, so we"),
           Create ("            --  do nothing."),
           Create ("            peek_count := peek_count - 1;"),
           Create ("         end if;"), Create ("         return t;"),
           Create ("      end if;"), Create ("   end get;"), Create (""),
           Create ("   procedure reset_peek is"),
           Create ("      --  Make it as if we have not peeked anything."),
           Create ("   begin"), Create ("      peek_count := 0;"),
           Create ("   end reset_peek;"), Create (""),
           Create ("   function peek return boxed_token is"),
           Create ("      t : boxed_token;"), Create ("   begin"),
           Create ("      if peek_count = buffered then"),
           Create ("         --  We have peeked all the buffered tokens"),
           Create ("         --  in the input stream, so next peeked"),
           Create ("         --  token should be got from lexical scanner."),
           Create ("         --  Also we must buffer that token in the"),
           Create ("         --  input stream. It is the difference between"),
           Create ("         --  peek and get."),
           Create ("         t := tbox (YYLex);"),
           Create
             ("         input_stream ((index + buffered) mod input_stream_size) := t;"),
           Create ("         buffered := buffered + 1;"),
           Create ("         if buffered > input_stream_size then"),
           Create
             ("            Text_IO.Put_Line (""Warning : input stream size exceed."""),
           Create
             ("                              & "" So token is lost in the input stream."" );"),
           Create ("         end if;"), Create (""), Create ("      else"),
           Create ("         --  We have not peeked all the buffered tokens,"),
           Create ("         --  so we peek next buffered token."),
           Create (""),
           Create
             ("         t := input_stream ((index+peek_count) mod input_stream_size);"),
           Create ("      end if;"), Create (""),
           Create ("      peek_count := peek_count + 1;"),
           Create ("      return t;"), Create ("   end peek;"), Create (""),
           Create ("   procedure unget (tok : in boxed_token) is"),
           Create ("   begin"), Create ("      --  First decrease the index."),
           Create ("      if index = 0 then"),
           Create ("         index := input_stream_size - 1;"),
           Create ("      else"), Create ("         index := index - 1;"),
           Create ("      end if;"),
           Create ("      input_stream (index) := tok;"),
           Create ("      buffered := buffered + 1;"),
           Create ("      if buffered > input_stream_size then"),
           Create
             ("        Text_IO.Put_Line (""Warning : input stream size exceed."""),
           Create
             ("                          & "" So token is lost in the input stream."" );"),
           Create ("      end if;"), Create (""),
           Create ("      if peek_count > 0 then"),
           Create ("         --  We are peeking tokens, so we must increase"),
           Create
             ("         --  peek_count to maintain the correct peeking position."),
           Create ("         peek_count := peek_count + 1;"),
           Create ("      end if;"), Create ("   end unget;"), Create (""),
           Create ("   end yyparser_input;"), Create (""), Create (""),
           Create ("   package body user_defined_errors is"), Create (""),
           Create ("      procedure parser_error(Message : in String) is"),
           Create ("      begin"),
           Create ("         yy_error_report.report_continuable_error"),
           Create ("            (yyparser_input.input_token.line_number,"),
           Create ("             yyparser_input.input_token.token_start,"),
           Create ("             yyparser_input.input_token.token_end,"),
           Create ("             Message,"), Create ("             True);"),
           Create
             ("         yy_error_report.total_errors := yy_error_report.total_errors + 1;"),
           Create ("      end parser_error;"), Create (""),
           Create ("      procedure parser_warning(Message : in String) is"),
           Create ("      begin"),
           Create ("         yy_error_report.report_continuable_error"),
           Create ("            (yyparser_input.input_token.line_number,"),
           Create ("             yyparser_input.input_token.token_start,"),
           Create ("             yyparser_input.input_token.token_end,"),
           Create ("             Message,"), Create ("             False);"),
           Create
             ("         yy_error_report.total_warnings := yy_error_report.total_warnings + 1;"),
           Create ("      end parser_warning;"), Create (""),
           Create ("    end user_defined_errors;"), Create (""), Create (""),
           Create ("    package body yyerror_recovery is"), Create (""),
           Create ("    max_forward_moves : constant Integer := 5;"),
           Create
             ("    --  Indicates how many tokens we will peek at most during error recovery."),
           Create (""),
           Create ("    type change_type is (replace, insert, delete);"),
           Create
             ("    --  Indicates what kind of change error recovery does to the input stream."),
           Create (""), Create ("    type correction_type is record"),
           Create
             ("       --  Indicates the correction error recovery does to the input stream."),
           Create ("       change    :   change_type;"),
           Create ("       score     :   Integer;"),
           Create ("       tokenbox  :   yyparser_input.boxed_token;"),
           Create ("    end record;"), Create (""),
           Create ("    procedure put_new_line is"),
           Create ("       line_number_string : constant string :="),
           Create
             ("          Integer'Image (yyparser_input.input_token.line_number);"),
           Create ("    begin"),
           Create ("       yy_error_report.put (line_number_string);"),
           Create
             ("       for i in 1 .. 5 - Integer (line_number_string'length) loop"),
           Create ("          yy_error_report.put ("" "");"),
           Create ("       end loop;"),
           Create
             ("       yy_error_report.put (yyparser_input.input_token.line.all);"),
           Create ("    end put_new_line;"), Create (""), Create (""),
           Create ("    procedure finale is"), Create ("    begin"),
           Create ("       if yy_error_report.total_errors > 0 then"),
           Create ("          yy_error_report.Put_Line ("""");"),
           Create
             ("          yy_error_report.put (""Ayacc.YYParse : "" & Natural'Image (yy_error_report.total_errors));"),
           Create ("          if yy_error_report.total_errors = 1 then"),
           Create
             ("             yy_error_report.Put_Line ("" syntax error found."");"),
           Create ("          else"),
           Create
             ("             yy_error_report.Put_Line ("" syntax errors found."");"),
           Create ("          end if;"),
           Create ("          yy_error_report.Finish_Output;"),
           Create ("          raise yy_error_report.Syntax_Error;"),
           Create ("       elsif yy_error_report.total_warnings > 0 then"),
           Create ("          yy_error_report.Put_Line ("""");"),
           Create
             ("          yy_error_report.put (""Ayacc.YYParse : "" & Natural'Image (yy_error_report.total_warnings));"),
           Create ("          if yy_error_report.total_warnings = 1 then"),
           Create
             ("             yy_error_report.Put_Line ("" syntax warning found."");"),
           Create ("          else"),
           Create
             ("             yy_error_report.Put_Line ("" syntax warnings found."");"),
           Create ("          end if;"), Create (""),
           Create ("          yy_error_report.Finish_Output;"),
           Create ("          raise yy_error_report.syntax_warning;"),
           Create ("       end if;"),
           Create ("       yy_error_report.Finish_Output;"),
           Create ("    end finale;"), Create (""),
           Create ("    procedure flag_token (error : in Boolean := True) is"),
           Create ("    --"), Create ("    --  OVERVIEW"),
           Create
             ("    --    This procedure will point out the position of the"),
           Create ("    --    current token."), Create ("    --"),
           Create ("    begin"), Create ("       if yy.error_flag > 0 then"),
           Create ("          --  We have not seen 3 valid shift yet, so we"),
           Create ("          --  do not need to report this error."),
           Create ("          return;"), Create ("       end if;"),
           Create (""), Create ("       if error then"),
           Create
             ("          yy_error_report.put (""Error""); --  5 characters for line number."),
           Create ("       else"),
           Create ("          yy_error_report.put(""OK   "");"),
           Create ("       end if;"), Create (""),
           Create
             ("       for i in 1 .. yyparser_input.input_token.token_start - 1 loop"),
           Create
             ("          if yyparser_input.input_token.line (i) = Ascii.ht then"),
           Create ("             yy_error_report.put (Ascii.ht);"),
           Create ("          else"),
           Create ("             yy_error_report.put ("" "");"),
           Create ("          end if;"), Create ("       end loop;"),
           Create ("       yy_error_report.Put_Line (""^"");"),
           Create ("    end flag_token;"), Create (""), Create (""),
           Create
             ("    procedure print_correction_message (correction : in correction_type) is"),
           Create ("    --"), Create ("    --  OVERVIEW"),
           Create
             ("    --    This is a local procedure used to print out the message"),
           Create ("    --    about the correction error recovery did."),
           Create ("    --"), Create ("    begin"),
           Create ("       if yy.error_flag > 0 then"),
           Create ("          --  We have not seen 3 valid shift yet, so we"),
           Create ("          --  do not need to report this error."),
           Create ("          return;"), Create ("      end if;"), Create (""),
           Create ("      flag_token;"),
           Create ("      case correction.change is"),
           Create ("         when delete =>"),
           Create ("            yy_error_report.put (""token delete "" );"),
           Create
             ("            user_defined_errors.parser_error (""token delete "" );"),
           Create (""), Create ("         when replace =>"),
           Create
             ("            yy_error_report.put (""token replaced by "" &"),
           Create
             ("                                 yy_tokens.Token'Image (correction.tokenbox.Token));"),
           Create
             ("            user_defined_errors.parser_error (""token replaced by "" &"),
           Create
             ("                                              yy_tokens.Token'Image (correction.tokenbox.token));"),
           Create (""), Create ("         when insert =>"),
           Create ("            yy_error_report.put (""inserted token "" &"),
           Create
             ("                                yy_tokens.token'Image (correction.tokenbox.token));"),
           Create
             ("            user_defined_errors.parser_error (""inserted token "" &"),
           Create
             ("                                              yy_tokens.Token'Image (correction.tokenbox.token));"),
           Create ("      end case;"), Create (""),
           Create ("      if yy.debug then"),
           Create
             ("         yy_error_report.Put_Line (""... Correction Score is"""),
           Create
             ("                                   & Integer'Image (correction.score));"),
           Create ("      else"),
           Create ("         yy_error_report.Put_Line ("""");"),
           Create ("      end if;"),
           Create ("      yy_error_report.Put_Line ("""");"),
           Create ("   end print_correction_message;"), Create (""),
           Create
             ("   procedure install_correction (correction : correction_type) is"),
           Create
             ("       --  This is a local procedure used to install the correction."),
           Create ("   begin"), Create ("      case correction.change is"),
           Create ("         when delete  => null;"),
           Create
             ("                          -- Since error found for current token,"),
           Create
             ("                          -- no state is changed for current token."),
           Create
             ("                          -- If we resume Parser now, Parser will"),
           Create
             ("                          -- try to read next token which has the"),
           Create
             ("                          -- affect of ignoring current token."),
           Create
             ("                          -- So for deleting correction, we need to"),
           Create ("                          -- do nothing."),
           Create
             ("         when replace => yyparser_input.unget(correction.tokenbox);"),
           Create
             ("         when insert  => yyparser_input.unget(yyparser_input.input_token);"),
           Create
             ("                         yyparser_input.input_token := null;"),
           Create
             ("                         yyparser_input.unget(correction.tokenbox);"),
           Create ("      end case;"), Create ("   end install_correction;"),
           Create (""), Create (""),
           Create ("   function simulate_moves return Integer is"),
           Create ("   --"), Create ("    --  OVERVIEW"),
           Create
             ("    --    This is a local procedure simulating the Parser work to"),
           Create
             ("    --    evaluate a potential correction. It will look at most"),
           Create
             ("    --    max_forward_moves tokens. It behaves very similarly as"),
           Create
             ("    --    the actual Parser except that it does not invoke user"),
           Create
             ("    --    action and it exits when either error is found or"),
           Create
             ("    --    the whole input is accepted. Simulate_moves also"),
           Create ("    --    collects and returns the score. Simulate_Moves"),
           Create ("    --    do the simulation on the copied state stack to"),
           Create ("    --    avoid changing the original one."), Create (""),
           Create ("       --  the score for each valid shift."),
           Create ("      shift_increment : constant Integer := 20;"),
           Create ("      --  the score for each valid reduce."),
           Create ("      reduce_increment : constant Integer := 10;"),
           Create ("      --  the score for accept action."),
           Create
             ("      accept_increment : Integer := 14 * max_forward_moves;"),
           Create ("      --  the decrement for error found."),
           Create
             ("      error_decrement : Integer := -10 * max_forward_moves;"),
           Create (""),
           Create
             ("      --  Indicates how many reduces made between last shift"),
           Create ("      --  and current shift."),
           Create ("      current_reduces : Integer := 0;"), Create (""),
           Create ("      --  Indicates how many reduces made till now."),
           Create ("      total_reduces : Integer := 0;"), Create (""),
           Create
             ("      --  Indicates how many tokens seen so far during simulation."),
           Create ("      tokens_seen : Integer := 0;"), Create (""),
           Create
             ("      score : Integer := 0; -- the score of the simulation."),
           Create (""),
           Create
             ("      The_Copied_Stack : array (0 .. yy.stack_size) of yy.parse_state;"),
           Create ("      The_Copied_Tos   : Integer;"),
           Create
             ("      The_Copied_Input_Token : yyparser_input.boxed_token;"),
           Create ("      Look_Ahead : Boolean := True;"), Create (""),
           Create ("   begin"), Create (""),
           Create ("      --  First we copy the state stack."),
           Create ("      for i in 0 .. yy.tos loop"),
           Create ("         The_Copied_Stack (i) := yy.state_stack (i);"),
           Create ("      end loop;"),
           Create ("      The_Copied_Tos := yy.tos;"),
           Create
             ("      The_Copied_Input_Token := yyparser_input.input_token;"),
           Create ("      --  Reset peek_count because each simulation"),
           Create ("      --  starts a new process of peeking."),
           Create ("      yyparser_input.reset_peek;"), Create (""),
           Create ("      --  Do the simulation."), Create ("      loop"),
           Create
             ("         --  We peek at most max_forward_moves tokens during simulation."),
           Create ("         exit when tokens_seen = max_forward_moves;"),
           Create (""),
           Create
             ("         --  The following codes is very similar the codes in Parser."),
           Create
             ("         yy.index := Shift_Reduce_Offset (yy.state_stack (yy.tos));"),
           Create
             ("         if Integer (Shift_Reduce_Matrix (yy.index).T) = yy.default then"),
           Create
             ("            yy.action := Integer (Shift_Reduce_Matrix (yy.index).Act);"),
           Create ("         else"), Create ("            if look_ahead then"),
           Create ("               look_ahead := False;"),
           Create
             ("               --  Since it is in simulation, we peek the token instead of"),
           Create ("               --  get the token."),
           Create
             ("               The_Copied_Input_Token  := yyparser_input.peek;"),
           Create ("            end if;"), Create ("            yy.action :="),
           Create
             ("              parse_action (The_Copied_Stack (The_Copied_Tos), The_Copied_Input_Token.token);"),
           Create ("         end if;"), Create (""),
           Create
             ("         if yy.action >= yy.first_shift_entry then  -- SHIFT"),
           Create ("            if yy.debug then"),
           Create
             ("               shift_debug (yy.action, The_Copied_Input_Token.token);"),
           Create ("            end if;"), Create (""),
           Create ("            --  Enter new state"),
           Create ("            The_Copied_Tos := The_Copied_Tos + 1;"),
           Create
             ("            The_Copied_Stack (The_Copied_Tos) := yy.action;"),
           Create (""), Create ("            --  Advance lookahead"),
           Create ("            look_ahead := True;"), Create (""),
           Create
             ("            score := score + shift_increment + current_reduces * reduce_increment;"),
           Create ("            current_reduces := 0;"),
           Create ("            tokens_seen := tokens_seen + 1;"), Create (""),
           Create
             ("         elsif yy.action = yy.error_code then       --  ERROR"),
           Create
             ("            score := score - total_reduces * reduce_increment;"),
           Create ("            exit; -- exit the loop for simulation."),
           Create (""),
           Create ("         elsif yy.action = yy.accept_code then"),
           Create ("            score := score + accept_increment;"),
           Create ("            exit; -- exit the loop for simulation."),
           Create (""), Create ("         else --  Reduce Action"),
           Create (""), Create ("            --  Convert action into a rule"),
           Create ("            yy.rule_id  := Rule (-1 * yy.action);"),
           Create (""), Create ("            --  Don't Execute User Action"),
           Create (""),
           Create ("            --  Pop RHS states and goto next state"),
           Create
             ("            The_Copied_Tos      := The_Copied_Tos - Rule_Length (yy.rule_id) + 1;"),
           Create
             ("            The_Copied_Stack (The_Copied_Tos) := goto_state (The_Copied_Stack (The_Copied_Tos - 1) ,"),
           Create
             ("                                 Get_LHS_Rule (yy.rule_id));"),
           Create (""), Create ("            --  Leave value stack alone"),
           Create (""), Create ("            if yy.debug then"),
           Create ("               reduce_debug (yy.rule_id,"),
           Create
             ("                  goto_state (The_Copied_Stack (The_Copied_Tos - 1),"),
           Create
             ("                              Get_LHS_Rule (yy.rule_id)));"),
           Create ("            end if;"), Create (""),
           Create
             ("            --  reduces only credited to score when a token can be shifted"),
           Create
             ("            --  but no more than 3 reduces can count between shifts"),
           Create ("            current_reduces := current_reduces + 1;"),
           Create ("            total_reduces := total_reduces + 1;"),
           Create (""), Create ("         end if;"), Create (""),
           Create ("      end loop; --  loop for simulation;"), Create (""),
           Create ("      yyparser_input.reset_peek;"), Create (""),
           Create ("      return score;"), Create ("   end simulate_moves;"),
           Create (""), Create (""), Create (""),
           Create
             ("   procedure primary_recovery (best_correction : in out correction_type;"),
           Create
             ("                               stop_score      : in Integer ) is"),
           Create ("    --"), Create ("    -- OVERVIEW"),
           Create
             ("    --    This is a local procedure used by try_recovery. This"),
           Create ("    --    procedure will try the following corrections :"),
           Create ("    --      1. Delete current token."),
           Create
             ("    --      2. Replace current token with any token acceptible"),
           Create ("    --         from current state, or,"),
           Create
             ("    --         Insert any one of the tokens acceptible from current state."),
           Create ("    --"), Create ("      token_code      : Integer;"),
           Create ("      new_score       : Integer;"),
           Create ("      the_boxed_token : yyparser_input.boxed_token;"),
           Create ("   begin"), Create (""),
           Create ("      --  First try to delete current token."),
           Create ("      if yy.debug then"),
           Create ("         yy_error_report.Put_Line (""trying to delete """),
           Create
             ("                                   & yy_tokens.token'Image (yyparser_input.input_token.token));"),
           Create ("      end if;"), Create (""),
           Create ("      best_correction.change := delete;"),
           Create
             ("      --  try to evaluate the correction. NOTE : simulating the Parser"),
           Create
             ("      --  from current state has affect of ignoring current token"),
           Create
             ("      --  because error was found for current token and no state"),
           Create ("      --  was pushed to state stack."),
           Create ("      best_correction.score := simulate_moves;"),
           Create ("      best_correction.tokenbox := null;"), Create (""),
           Create ("      --  If the score is less than stop_score, we try"),
           Create
             ("      --  the 2nd kind of corrections, that is, replace or insert."),
           Create ("      if best_correction.score < stop_score then"),
           Create
             ("         for i in shift_reduce_offset (yy.state_stack (yy.tos)) .."),
           Create
             ("                 (shift_reduce_offset (yy.state_stack (yy.tos) + 1) - 1) loop"),
           Create
             ("            --  We try to use the acceptible token from current state"),
           Create
             ("            --  to replace current token or try to insert the acceptible token."),
           Create
             ("            token_code := Integer (Shift_Reduce_Matrix (i).t);"),
           Create
             ("            --  yy.default is not a valid token, we must exit."),
           Create ("            exit when token_code = yy.default;"),
           Create (""),
           Create
             ("            the_boxed_token := yyparser_input.tbox (yy_tokens.token'val(token_code));"),
           Create ("            for change in replace .. insert loop"),
           Create ("               --  We try replacing and the inserting."),
           Create ("               case change is"),
           Create
             ("                  when replace => yyparser_input.unget(the_boxed_token);"),
           Create
             ("                               -- put the_boxed_token into the input stream"),
           Create
             ("                               -- has the affect of replacing current token"),
           Create
             ("                               -- because current token has been retrieved"),
           Create
             ("                               -- but no state was change because of the error."),
           Create ("                               if yy.debug then"),
           Create
             ("                                  yy_error_report.Put_Line (""trying to replace """),
           Create
             ("                                          & yy_tokens.token'Image"),
           Create
             ("                                             (yyparser_input.input_token.token)"),
           Create ("                                          & "" with """),
           Create
             ("                                          & yy_tokens.token'Image (the_boxed_token.token));"),
           Create ("                               end if;"),
           Create
             ("                  when insert  => yyparser_input.unget(yyparser_input.input_token);"),
           Create
             ("                               yyparser_input.unget(the_boxed_token);"),
           Create ("                               if yy.debug then"),
           Create
             ("                                  yy_error_report.Put_Line (""trying to insert """),
           Create
             ("                                           & yy_tokens.token'Image (the_boxed_token.token)"),
           Create
             ("                                           & "" before """),
           Create
             ("                                           & yy_tokens.token'Image ("),
           Create
             ("                                                yyparser_input.input_token.token));"),
           Create ("                               end if;"),
           Create ("               end case;"), Create (""),
           Create ("               -- Evaluate the correction."),
           Create ("               new_score := simulate_moves;"), Create (""),
           Create ("               if new_score > best_correction.score then"),
           Create
             ("                  -- We find a higher score, so we overwrite the old one."),
           Create
             ("                  best_correction := (change, new_score, the_boxed_token);"),
           Create ("               end if;"), Create (""),
           Create
             ("               -- We have change the input stream when we do replacing or"),
           Create ("               -- inserting. So we must undo the affect."),
           Create ("               declare"),
           Create
             ("                  ignore_result : yyparser_input.boxed_token;"),
           Create ("               begin"),
           Create ("                  case change is"),
           Create
             ("                    when replace => ignore_result := yyparser_input.get;"),
           Create
             ("                    when insert  => ignore_result := yyparser_input.get;"),
           Create
             ("                                    ignore_result := yyparser_input.get;"),
           Create ("                  end case;"),
           Create ("               end;"), Create (""),
           Create
             ("               --  If we got a score higher than stop score, we"),
           Create ("               --  feel it is good enough, so we exit."),
           Create
             ("               exit when best_correction.score > stop_score;"),
           Create (""),
           Create ("            end loop;  --  change in replace .. insert"),
           Create (""),
           Create
             ("            --  If we got a score higher than stop score, we"),
           Create ("            --  feel it is good enough, so we exit."),
           Create
             ("            exit when best_correction.score > stop_score;"),
           Create (""),
           Create ("         end loop;  --  i in shift_reduce_offset..."),
           Create (""),
           Create ("      end if; --  best_correction.score < stop_score;"),
           Create (""), Create ("   end primary_recovery;"), Create (""),
           Create (""), Create ("   procedure try_recovery is"),
           Create ("    --"), Create ("    -- OVERVIEW"),
           Create
             ("    --   This is the main procedure doing error recovery."),
           Create
             ("    --   During the process of error recovery, we use score to"),
           Create
             ("    --   evaluate the potential correction. When we try a potential"),
           Create
             ("    --   correction, we will peek some future tokens and simulate"),
           Create
             ("    --   the work of Parser. Any valid shift, reduce or accept action"),
           Create
             ("    --   in the simulation leading from a potential correction"),
           Create
             ("    --   will increase the score of the potential correction."),
           Create
             ("    --   Any error found during the simulation will decrease the"),
           Create
             ("    --   score of the potential correction and stop the simulation."),
           Create
             ("    --   Since we limit the number of tokens being peeked, the"),
           Create
             ("    --   simulation will stop no matter what the correction is."),
           Create
             ("    --   If the score of a potential correction is higher enough,"),
           Create
             ("    --   we will accept that correction and install and let the Parser"),
           Create
             ("    --   continues. During the simulation, we will do almost the"),
           Create
             ("    --   same work as the actual Parser does, except that we do"),
           Create
             ("    --   not invoke any user actions and we collect the score."),
           Create
             ("    --   So we will use the state_stack of the Parser. In order"),
           Create
             ("    --   to avoid change the value of state_stack, we will make"),
           Create
             ("    --   a copy of the state_stack and the simulation is done"),
           Create
             ("    --   on the copy. Below is the outline of sequence of corrections"),
           Create ("    --   the error recovery algorithm tries:"),
           Create ("    --      1. Delete current token."),
           Create
             ("    --      2. Replace current token with any token acceptible"),
           Create ("    --         from current state, or,"),
           Create
             ("    --         Insert any one of the tokens acceptible from current state."),
           Create
             ("    --      3. If previous parser action is shift, back up one state,"),
           Create ("    --         and try the corrections in 1 and 2 again."),
           Create
             ("    --      4. If none of the scores of the corrections above are highed"),
           Create
             ("    --         enough, we invoke the handle_error in Ayacc."),
           Create ("    --"), Create ("      correction : correction_type;"),
           Create
             ("      backed_up  : Boolean := False; -- indicates whether or not we backed up"),
           Create
             ("                                     -- during error recovery."),
           Create
             ("      -- scoring : evaluate a potential correction with a number. high is good"),
           Create
             ("      min_ok_score : constant Integer := 70;       -- will rellluctantly use"),
           Create
             ("      stop_score   : constant Integer := 100;      -- this or higher is best."),
           Create ("   begin"), Create (""),
           Create ("      -- First try recovery without backing up."),
           Create ("      primary_recovery (correction, stop_score);"),
           Create (""), Create ("      if correction.score < stop_score then"),
           Create
             ("         --  The score of the correction is not high enough,"),
           Create
             ("         --  so we try to back up and try more corrections."),
           Create
             ("         --  But we can back up only if previous Parser action"),
           Create ("         --  is shift."),
           Create ("         if previous_action >= yy.first_shift_entry then"),
           Create
             ("            --  Previous action is a shift, so we back up."),
           Create ("            backed_up := True;"), Create (""),
           Create ("            -- we put back the input token and"),
           Create
             ("            -- roll back the state stack and input token."),
           Create
             ("            yyparser_input.unget (yyparser_input.input_token);"),
           Create
             ("            yyparser_input.input_token := yyparser_input.previous_token;"),
           Create ("            yy.tos := yy.tos - 1;"), Create (""),
           Create ("            --  Then we try recovery again"),
           Create ("            primary_recovery (correction, stop_score);"),
           Create ("         end if;"),
           Create ("      end if;  --  correction_score < stop_score"),
           Create (""),
           Create ("      --  Now we have try all possible correction."),
           Create ("      --  The highest score is in correction."),
           Create ("      if correction.score >= min_ok_score then"),
           Create ("         --  We accept this correction."), Create (""),
           Create
             ("         --  First, if the input token resides on the different line"),
           Create
             ("         --  of previous token and we have not backed up, we must"),
           Create
             ("         --  output the new line before we printed the error message."),
           Create
             ("         --  If we have backed up, we do nothing here because"),
           Create ("         --  previous line has been output."),
           Create ("         if not backed_up and then"),
           Create ("            (line_number <"),
           Create
             ("               yyparser_input.input_token.line_number ) then"),
           Create ("            put_new_line;"),
           Create
             ("            line_number := yyparser_input.input_token.line_number;"),
           Create ("         end if;"), Create (""),
           Create ("         print_correction_message(correction);"),
           Create ("         install_correction(correction);"), Create (""),
           Create ("      else"),
           Create
             ("         --  No score is high enough, we try to invoke handle_error"),
           Create
             ("         --  First, if we backed up during error recovery, we now must"),
           Create ("         --  try to undo the affect of backing up."),
           Create ("         if backed_up then"),
           Create
             ("            yyparser_input.input_token := yyparser_input.get;"),
           Create ("            yy.tos := yy.tos + 1;"),
           Create ("         end if;"), Create (""),
           Create
             ("         --  Output the new line if necessary because the"),
           Create ("         --  new line has not been output yet."),
           Create ("         if line_number <"),
           Create ("             yyparser_input.input_token.line_number then"),
           Create ("            put_new_line;"),
           Create
             ("            line_number := yyparser_input.input_token.line_number;"),
           Create ("         end if;"), Create (""),
           Create ("         if yy.debug then"),
           Create ("            if not backed_up then"),
           Create
             ("               yy_error_report.Put_Line (""can't back yp over last token..."");"),
           Create ("            end if;"),
           Create
             ("            yy_error_report.Put_Line (""1st level recovery failed, going to 2nd level..."");"),
           Create ("         end if;"), Create (""),
           Create
             ("         --  Point out the position of the token on which error occurs."),
           Create ("         flag_token;"), Create (""),
           Create
             ("         --  count it as error if it is a new error. NOTE : if correction is accepted, total_errors"),
           Create
             ("         --  count will be increase during error reporting."),
           Create ("         if yy.error_flag = 0 then --  brand new error"),
           Create
             ("            yy_error_report.total_errors := yy_error_report.total_errors + 1;"),
           Create ("         end if;"), Create (""),
           Create ("         --  Goes to 2nd level."),
           Create ("         handle_error;"), Create (""),
           Create ("      end if; --  correction.score >= min_ok_score"),
           Create (""),
           Create
             ("      --  No matter what happen, let the parser move forward."),
           Create ("      yy.look_ahead := True;"), Create (""),
           Create ("   end try_recovery;"), Create (""), Create (""),
           Create ("   end yyerror_recovery;"), Create (""), Create (""),
           Create ("-- END OF UMASS CODES."), Create (""), Create ("   begin"),
           Create
             ("      --  initialize by pushing state 0 and getting the first input symbol"),
           Create ("      yy.state_stack (yy.tos) := 0;"),
           Create ("-- UMASS CODES :"),
           Create ("      yy_error_report.Initialize_Output;"),
           Create ("      --  initialize input token and previous token"),
           Create
             ("      yyparser_input.input_token := new yyparser_input.tokenbox;"),
           Create ("      yyparser_input.input_token.line_number := 0;"),
           Create ("-- END OF UMASS CODES."), Create (""), Create (""),
           Create ("      loop"),
           Create
             ("         yy.index := Shift_Reduce_Offset (yy.state_stack (yy.tos));"),
           Create
             ("         if Integer (Shift_Reduce_Matrix (yy.index).T) = yy.default then"),
           Create
             ("            yy.action := Integer (Shift_Reduce_Matrix (yy.index).Act);"),
           Create ("         else"),
           Create ("            if yy.look_ahead then"),
           Create ("               yy.look_ahead := False;"),
           Create ("-- UMASS CODES :"),
           Create
             ("               --  Let Parser get the input from yyparser_input instead of lexical"),
           Create
             ("               --  scanner and maintain previous_token and input_token."),
           Create
             ("               yyparser_input.previous_token := yyparser_input.input_token;"),
           Create
             ("               yyparser_input.input_token := yyparser_input.get;"),
           Create
             ("               yy.input_symbol := yyparser_input.input_token.token;"),
           Create ("-- END OF UMASS CODES."), Create (""),
           Create ("-- UCI CODES DELETED :"),
           Create ("               yy.input_symbol := YYLex;"),
           Create ("-- END OF UCI CODES DELETED."),
           Create ("            end if;"),
           Create
             ("            yy.action := parse_action (yy.state_stack (yy.tos), yy.input_symbol);"),
           Create ("         end if;"), Create (""),
           Create ("-- UMASS CODES :"),
           Create
             ("         --   If input_token is not on the line yyerror_recovery.line_number,"),
           Create
             ("         --   we just get to a new line. So we output the new line to"),
           Create
             ("         --   file of error report. But if yy.action is error, we"),
           Create
             ("         --   will not output the new line because we will do error"),
           Create
             ("         --   recovery and during error recovery, we may back up"),
           Create
             ("         --   which may cause error reported on previous line."),
           Create
             ("         --   So if yy.action is error, we will let error recovery"),
           Create ("         --   to output the new line."),
           Create ("         if (yyerror_recovery.line_number <"),
           Create
             ("             yyparser_input.input_token.line_number ) and then"),
           Create ("            yy.action /= yy.error_code then"),
           Create ("            put_new_line;"),
           Create
             ("            yyerror_recovery.line_number := yyparser_input.input_token.line_number;"),
           Create ("         end if;"), Create ("-- END OF UMASS CODES."),
           Create (""),
           Create
             ("         if yy.action >= yy.first_shift_entry then  --  SHIFT"),
           Create (""), Create ("            if yy.debug then"),
           Create ("               shift_debug (yy.action, yy.input_symbol);"),
           Create ("            end if;"), Create (""),
           Create ("            --  Enter new state"),
           Create ("            if yy.tos = yy.stack_size then"),
           Create
             ("               Text_IO.Put_Line ("" Stack size exceeded on state_stack"");"),
           Create ("               raise yy_tokens.Syntax_Error;"),
           Create ("            end if;"),
           Create ("            yy.tos                  := yy.tos + 1;"),
           Create ("            yy.state_stack (yy.tos) := yy.action;"),
           Create ("-- UMASS CODES :"),
           Create
             ("            --   Set value stack only if valuing is True."),
           Create ("            if yyerror_recovery.valuing then"),
           Create ("-- END OF UMASS CODES."),
           Create ("            yy.value_stack (yy.tos) := YYLVal;"),
           Create ("-- UMASS CODES :"), Create ("            end if;"),
           Create ("-- END OF UMASS CODES."), Create (""),
           Create
             ("            if yy.error_flag > 0 then  --  indicate a valid shift"),
           Create ("               yy.error_flag := yy.error_flag - 1;"),
           Create ("            end if;"), Create (""),
           Create ("            --  Advance lookahead"),
           Create ("            yy.look_ahead := True;"), Create (""),
           Create
             ("         elsif yy.action = yy.error_code then       -- ERROR"),
           Create ("-- UMASS CODES :"), Create ("            try_recovery;"),
           Create ("-- END OF UMASS CODES."), Create (""),
           Create ("-- UCI CODES DELETED :"),
           Create ("            handle_error;"),
           Create ("-- END OF UCI CODES DELETED."), Create (""),
           Create ("         elsif yy.action = yy.accept_code then"),
           Create ("            if yy.debug then"),
           Create
             ("               Text_IO.Put_Line (""  --  Ayacc.YYParse: Accepting Grammar..."");"),
           Create ("-- UMASS CODES :"),
           Create
             ("               yy_error_report.Put_Line (""Ayacc.YYParse: Accepting Grammar..."");"),
           Create ("-- END OF UMASS CODES."), Create ("            end if;"),
           Create ("            exit;"), Create (""),
           Create ("         else --  Reduce Action"), Create (""),
           Create ("            --  Convert action into a rule"),
           Create ("            yy.rule_id := Rule (-1 * yy.action);"),
           Create (""), Create ("            --  Execute User Action"),
           Create ("            --  user_action(yy.rule_id);"),
           Create ("-- UMASS CODES :"), Create (""),
           Create
             ("            --   Only invoke semantic action if valuing is True."),
           Create
             ("            --   And if exception is raised during semantic action"),
           Create
             ("            --   and total_errors is not zero, we set valuing to False"),
           Create
             ("            --   because we assume that error recovery causes the exception"),
           Create
             ("            --   and we no longer want to invoke any semantic action."),
           Create ("            if yyerror_recovery.valuing then"),
           Create ("               begin"), Create ("-- END OF UMASS CODES."),
           Create (""), Create ("            case yy.rule_id is"),
           Create ("               pragma Style_Checks (Off);"), Create ("%%"),
           Create (""), Create ("               pragma Style_Checks (On);"),
           Create (""), Create ("               when others => null;"),
           Create ("            end case;"), Create (""),
           Create ("-- UMASS CODES :"),
           Create ("            --   Corresponding to the codes above."),
           Create ("            exception"),
           Create ("               when others =>"),
           Create
             ("                  if yy_error_report.total_errors > 0 then"),
           Create ("                     yyerror_recovery.valuing := False;"),
           Create
             ("                     --  We no longer want to invoke any semantic action."),
           Create ("                  else"),
           Create
             ("                     --  this exception is not caused by syntax error,"),
           Create ("                     --  so we reraise anyway."),
           Create ("                     yy_error_report.Finish_Output;"),
           Create ("                     raise;"),
           Create ("                  end if;"), Create ("            end;"),
           Create ("            end if;"), Create (""),
           Create ("-- END OF UMASS CODES."),
           Create ("            --  Pop RHS states and goto next state"),
           Create
             ("            yy.tos := yy.tos - Rule_Length (yy.rule_id) + 1;"),
           Create ("            if yy.tos > yy.stack_size then"),
           Create
             ("               Text_IO.Put_Line ("" Stack size exceeded on state_stack"");"),
           Create ("-- UMASS CODES :"),
           Create
             ("               yy_error_report.Put_Line ("" Stack size exceeded on state_stack"");"),
           Create ("               yyerror_recovery.finale;"),
           Create ("-- END OF UMASS CODES."),
           Create ("               raise yy_tokens.Syntax_Error;"),
           Create ("            end if;"),
           Create
             ("            yy.state_stack (yy.tos) := goto_state (yy.state_stack (yy.tos - 1),"),
           Create
             ("                                                   Get_LHS_Rule (yy.rule_id));"),
           Create (""), Create ("-- UMASS CODES :"),
           Create
             ("            --   Set value stack only if valuing is True."),
           Create ("            if yyerror_recovery.valuing then"),
           Create ("-- END OF UMASS CODES."),
           Create ("            yy.value_stack (yy.tos) := YYVal;"),
           Create ("-- UMASS CODES :"), Create ("            end if;"),
           Create ("-- END OF UMASS CODES."), Create (""),
           Create ("            if yy.debug then"),
           Create ("               reduce_debug (yy.rule_id,"),
           Create
             ("                  goto_state (yy.state_stack (yy.tos - 1),"),
           Create
             ("                              Get_LHS_Rule (yy.rule_id)));"),
           Create ("            end if;"), Create (""),
           Create ("         end if;"), Create ("-- UMASS CODES :"),
           Create (""),
           Create
             ("        --  If the error flag is set to zero at current token,"),
           Create ("        --  we flag current token out."),
           Create
             ("        if yyerror_recovery.previous_error_flag > 0 and then"),
           Create ("           yy.error_flag = 0 then"),
           Create ("           yyerror_recovery.flag_token (error => False);"),
           Create ("        end if;"), Create (""),
           Create ("        --   save the action made and error flag."),
           Create ("        yyerror_recovery.previous_action := yy.action;"),
           Create
             ("        yyerror_recovery.previous_error_flag := yy.error_flag;"),
           Create ("-- END OF UMASS CODES."), Create (""),
           Create ("      end loop;"), Create ("-- UMASS CODES :"),
           Create (""), Create ("     finale;"),
           Create ("-- END OF UMASS CODES."), Create (""),
           Create ("   end YYParse;"), Create (""));  -- End of File Contents
   end Initialize;

   procedure Open is
   begin
      File_Pointer := Yyparse_Template_File'First;
   end Open;

   procedure Close is
   begin
      File_Pointer := 0;
   end Close;

   procedure Read (S : out String; Length : out Integer) is
      Next_Line : constant String :=
        String_Pkg.Value (Yyparse_Template_File (File_Pointer));
   begin
      S      := Next_Line & (1 .. S'Length - Next_Line'Length => ' ');
      Length := Next_Line'Length;

      File_Pointer := File_Pointer + 1;
   exception
      when Constraint_Error =>
         if Is_End_Of_File then
            raise End_Error;
         else
            raise Status_Error;
         end if;
   end Read;

   function Is_End_Of_File return Boolean is
   begin
      return File_Pointer = (Yyparse_Template_File'Last + 1);
   end Is_End_Of_File;

end Parse_Template_File;
