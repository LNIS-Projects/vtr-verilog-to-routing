%{
/*
Copyright (c) 2009 Peter Andrew Jamieson (jamieson.peter@gmail.com)

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
*/
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "odin_types.h"
#include "ast_util.h"
#include "parse_making_ast.h"

#define PARSE {printf("here\n");}
extern int yylineno;
#ifndef YYLINENO
	#define YYLINENO yylineno
#endif

void yyerror(const char *str){	fprintf(stderr,"error in parsing: (%s)::%d\n",str, yylineno-1);	exit(-1);}
int yywrap(){	return 1;}
int yyparse();
int yylex(void);


%}

%union{
	char *id_name;
	char *num_value;
	ast_node_t *node;
}

%token <id_name> vSYMBOL_ID
%token <num_value> vNUMBER
%token <num_value> vDELAY_ID
%token vALWAYS vINITIAL vSPECIFY vAND vASSIGN vBEGIN vCASE vDEFAULT vDEFINE vELSE vEND vENDCASE
%token vENDMODULE vENDSPECIFY vENDGENERATE vENDFUNCTION vIF vINOUT vINPUT vMODULE vGENERATE vFUNCTION
%token vOUTPUT vPARAMETER vLOCALPARAM vPOSEDGE vREG vWIRE vXNOR vXOR vDEFPARAM voANDAND vNAND vNEGEDGE vNOR vNOT vOR vFOR
%token voOROR voLTE voGTE voPAL voSLEFT voSRIGHT voASRIGHT voEQUAL voNOTEQUAL voCASEEQUAL
%token voCASENOTEQUAL voXNOR voNAND voNOR vWHILE vINTEGER vCLOG2 vGENVAR
%token vPLUS_COLON vMINUS_COLON vSPECPARAM voUNSIGNED voSIGNED vSIGNED vCFUNC
%token '?' ':' '|' '^' '&' '<' '>' '+' '-' '*' '/' '%' '(' ')' '{' '}' '[' ']' '~' '!' ';' '#' ',' '.' '@' '='
%token vNOT_SUPPORT 

%right '?' ':'
%left voOROR
%left voANDAND
%left '|'
%left '^' voXNOR voNOR
%left '&' voNAND
%left voEQUAL voNOTEQUAL voCASEEQUAL voCASENOTEQUAL
%left voGTE voLTE '<' '>'
%left voSLEFT voSRIGHT voASRIGHT
%left '+' '-'
%left '*' '/' '%'
%right voPOWER
%left '~' '!'
%left '{' '}'
%left UOR
%left UAND
%left UNOT
%left UNAND
%left UNOR
%left UXNOR
%left UXOR
%left ULNOT
%left UADD
%left UMINUS

%nonassoc LOWER_THAN_ELSE
%nonassoc vELSE

%type <node> source_text items module list_of_module_items list_of_function_items module_item function_item module_parameters module_ports
%type <node> list_of_parameter_declaration parameter_declaration specparam_declaration list_of_port_declaration port_declaration signed_port_declaration defparam_declaration
%type <node> function_declaration function_input_declaration
%type <node> input_declaration output_declaration inout_declaration variable_list function_output_variable function_id_and_output_variable
%type <node> integer_type_variable_list variable integer_type_variable
%type <node> net_declaration integer_declaration function_instantiation genvar_declaration
%type <node> continuous_assign multiple_inputs_gate_instance list_of_single_input_gate_declaration_instance
%type <node> list_of_multiple_inputs_gate_declaration_instance list_of_module_instance
%type <node> gate_declaration single_input_gate_instance
%type <node> module_instantiation module_instance function_instance list_of_module_connections list_of_function_connections
%type <node> list_of_multiple_inputs_gate_connections
%type <node> module_connection always statement function_statement blocking_assignment
%type <node> non_blocking_assignment conditional_statement case_statement case_item_list case_items seq_block
%type <node> stmt_list delay_control event_expression_list event_expression loop_statement
%type <node> expression primary expression_list module_parameter
%type <node> list_of_module_parameters localparam_declaration
%type <node> specify_block list_of_specify_items
%type <node> c_function_expression_list c_function
%type <node> initial_block list_of_blocking_assignment
%type <node> list_of_generate_items generate_item generate loop_generate_construct if_generate_construct 
%type <node> case_generate_construct case_generate_item_list case_generate_items generate_block

%%

// 1 Source Text
source_text:
	items	{next_parsed_verilog_file($1);}
	;

items:
	items module	{($1 != NULL)? $$ = newList_entry($1, $2): $$ = newList(FILE_ITEMS, $2);}
	| module	{$$ = newList(FILE_ITEMS, $1);}
	;

module:
	vMODULE vSYMBOL_ID module_parameters module_ports ';' list_of_module_items vENDMODULE			{$$ = newModule($2, $3, $4, $6, yylineno);}
	| vMODULE vSYMBOL_ID module_parameters ';' list_of_module_items vENDMODULE						{$$ = newModule($2, $3, NULL, $5, yylineno);}
	| vMODULE vSYMBOL_ID module_ports ';' list_of_module_items vENDMODULE							{$$ = newModule($2, NULL, $3, $5, yylineno);}
	| vMODULE vSYMBOL_ID ';' list_of_module_items vENDMODULE										{$$ = newModule($2, NULL, NULL, $4, yylineno);}
	;

module_parameters:
	'#' '(' list_of_parameter_declaration ')'			{$$ = $3;}
	| '#' '(' list_of_parameter_declaration ',' ')'		{$$ = $3;}
	| '#' '(' ')'										{$$ = NULL;}
	;

list_of_parameter_declaration:
	list_of_parameter_declaration ',' vPARAMETER vSIGNED variable	{$$ = newList_entry($1, markAndProcessParameterWith(MODULE,PARAMETER, $5, true));}
	| list_of_parameter_declaration ',' vPARAMETER variable			{$$ = newList_entry($1, markAndProcessParameterWith(MODULE,PARAMETER, $4, false));}
	| list_of_parameter_declaration ',' variable					{$$ = newList_entry($1, markAndProcessParameterWith(MODULE,PARAMETER, $3, false));} // force unsigned; error thrown if preceding parameter is signed
	| vPARAMETER vSIGNED variable									{$$ = newList(VAR_DECLARE_LIST, markAndProcessParameterWith(MODULE,PARAMETER, $3, true));}
	| vPARAMETER variable											{$$ = newList(VAR_DECLARE_LIST, markAndProcessParameterWith(MODULE,PARAMETER, $2, false));}
	;

module_ports:
	'(' list_of_port_declaration ')'					{$$ = $2;}
	| '(' list_of_port_declaration ',' ')'				{$$ = $2;}
	| '(' ')'											{$$ = NULL;}
	;

list_of_port_declaration:
	list_of_port_declaration ',' port_declaration		{$$ = newList_entry($1, $3);}
	| port_declaration									{$$ = newList(VAR_DECLARE_LIST, $1);}
	;
	
port_declaration:
	signed_port_declaration						{$$ = $1;}
	| vINPUT vWIRE variable						{$$ = markAndProcessPortWith(MODULE, INPUT, WIRE, $3, false);}
	| vOUTPUT vWIRE variable					{$$ = markAndProcessPortWith(MODULE, OUTPUT, WIRE, $3, false);}
	| vINOUT vWIRE variable						{$$ = markAndProcessPortWith(MODULE, INOUT, WIRE, $3, false);}
	| vINPUT vREG variable						{$$ = markAndProcessPortWith(MODULE, INPUT, REG, $3, false);}
	| vOUTPUT vREG variable						{$$ = markAndProcessPortWith(MODULE, OUTPUT, REG, $3, false);}
	| vINOUT vREG variable						{$$ = markAndProcessPortWith(MODULE, INOUT, REG, $3, false);}
	| vINPUT variable							{$$ = markAndProcessPortWith(MODULE, INPUT, NO_ID, $2, false);}
	| vOUTPUT variable							{$$ = markAndProcessPortWith(MODULE, OUTPUT, NO_ID, $2, false);}
	| vINOUT variable							{$$ = markAndProcessPortWith(MODULE, INOUT, NO_ID, $2, false);}
	| variable									{$$ = $1;}
	;

signed_port_declaration:
	vINPUT vWIRE vSIGNED variable				{$$ = markAndProcessPortWith(MODULE, INPUT, WIRE, $4, true);}
	| vOUTPUT vWIRE vSIGNED variable			{$$ = markAndProcessPortWith(MODULE, OUTPUT, WIRE, $4, true);}
	| vINOUT vWIRE vSIGNED variable				{$$ = markAndProcessPortWith(MODULE, INOUT, WIRE, $4, true);}
	| vINPUT vREG vSIGNED variable				{$$ = markAndProcessPortWith(MODULE, INPUT, REG, $4, true);}
	| vOUTPUT vREG vSIGNED variable				{$$ = markAndProcessPortWith(MODULE, OUTPUT, REG, $4, true);}
	| vINOUT vREG vSIGNED variable				{$$ = markAndProcessPortWith(MODULE, INOUT, REG, $4, true);}
	| vINPUT vINTEGER integer_type_variable		{$$ = markAndProcessPortWith(MODULE, INPUT, INTEGER, $3, true);}
	| vOUTPUT vINTEGER integer_type_variable	{$$ = markAndProcessPortWith(MODULE, OUTPUT, INTEGER, $3, true);}
	| vINOUT vINTEGER integer_type_variable		{$$ = markAndProcessPortWith(MODULE, INOUT, INTEGER, $3, true);}
	| vINPUT vSIGNED variable					{$$ = markAndProcessPortWith(MODULE, INPUT, NO_ID, $3, true);}
	| vOUTPUT vSIGNED variable					{$$ = markAndProcessPortWith(MODULE, OUTPUT, NO_ID, $3, true);}
	| vINOUT vSIGNED variable					{$$ = markAndProcessPortWith(MODULE, INOUT, NO_ID, $3, true);}
	;

list_of_module_items:
	list_of_module_items module_item	{$$ = newList_entry($1, $2);}
	| module_item						{$$ = newList(MODULE_ITEMS, $1);}
	;

module_item:
	parameter_declaration	{$$ = $1;}
	| input_declaration	 	{$$ = $1;}
	| output_declaration 	{$$ = $1;}
	| inout_declaration 	{$$ = $1;}
	| specify_block			{$$ = $1;}
	| generate_item			{$$ = $1;}
	| generate				{$$ = $1;}
	;

list_of_generate_items:
	list_of_generate_items generate_item	{$$ = newList_entry($1, $2);}
	| generate_item							{$$ = newList(BLOCK, $1);}

generate_item:
	localparam_declaration		{$$ = $1;}
	| net_declaration 			{$$ = $1;}
	| genvar_declaration		{$$ = $1;}
	| integer_declaration 		{$$ = $1;}
	| continuous_assign			{$$ = $1;}
	| gate_declaration			{$$ = $1;}
	| module_instantiation		{$$ = $1;}
	| function_declaration		{$$ = $1;}
	| initial_block				{$$ = $1;}
	| always					{$$ = $1;}
	| defparam_declaration		{$$ = $1;}
	| c_function ';'			{$$ = $1;}
	| if_generate_construct		{$$ = $1;}
	| case_generate_construct	{$$ = $1;}
	| loop_generate_construct	{$$ = $1;}
	;

function_declaration:
	vFUNCTION function_output_variable ';' list_of_function_items vENDFUNCTION	{$$ = newFunction($2, $4, yylineno); }
	;

initial_block:
	vINITIAL statement	{$$ = newInitial($2, yylineno); }
	;

	/* Specify is unsynthesizable, we discard everything within */
specify_block:
	vSPECIFY list_of_specify_items vENDSPECIFY	{$$ = $2;}
	;

list_of_specify_items:
	list_of_specify_items specparam_declaration			{$$ = $2;}
	| specparam_declaration								{$$ = $1;}
	;

specparam_declaration:
	'(' primary voPAL expression ')' '=' primary ';'	{free_whole_tree($2); free_whole_tree($4); free_whole_tree($7); $$ = NULL;}
	| vSPECPARAM variable_list ';'						{free_whole_tree($2); $$ = NULL;}
	;
	
list_of_function_items:
	list_of_function_items function_item	{$$ = newList_entry($1, $2);}
	| function_item				{$$ = newList(FUNCTION_ITEMS, $1);}
	;

function_item: 
	parameter_declaration			{$$ = $1;}
	| function_input_declaration	{$$ = $1;}
	| net_declaration 				{$$ = $1;}
	| integer_declaration 			{$$ = $1;}
	| continuous_assign				{$$ = $1;}
	| defparam_declaration			{$$ = $1;}
	| function_statement			{$$ = $1;} //TODO It`s temporary
	;

function_input_declaration:
	vINPUT vSIGNED variable_list ';'	{$$ = markAndProcessSymbolListWith(FUNCTION, INPUT, $3, true);}
	| vINPUT variable_list ';'			{$$ = markAndProcessSymbolListWith(FUNCTION, INPUT, $2, false);}
	;

parameter_declaration:
	vPARAMETER vSIGNED variable_list ';'	{$$ = markAndProcessSymbolListWith(MODULE,PARAMETER, $3, true);}
	| vPARAMETER variable_list ';'			{$$ = markAndProcessSymbolListWith(MODULE,PARAMETER, $2, false);}
	;

localparam_declaration:
	vLOCALPARAM vSIGNED variable_list ';'	{$$ = markAndProcessSymbolListWith(MODULE,LOCALPARAM, $3, true);}
	| vLOCALPARAM variable_list ';'			{$$ = markAndProcessSymbolListWith(MODULE,LOCALPARAM, $2, false);}
	;

defparam_declaration:
	vDEFPARAM variable_list ';'	{$$ = newDefparam(MODULE_PARAMETER_LIST, $2, yylineno);}
	;

input_declaration:
	vINPUT net_declaration					{$$ = markAndProcessSymbolListWith(MODULE,INPUT, $2, false);}
	| vINPUT integer_declaration			{$$ = markAndProcessSymbolListWith(MODULE,INPUT, $2, true);}
	| vINPUT vSIGNED variable_list ';'		{$$ = markAndProcessSymbolListWith(MODULE,INPUT, $3, true);}
	| vINPUT variable_list ';'				{$$ = markAndProcessSymbolListWith(MODULE,INPUT, $2, false);}
	;

output_declaration:
	vOUTPUT net_declaration					{$$ = markAndProcessSymbolListWith(MODULE,OUTPUT, $2, false);}
	| vOUTPUT integer_declaration			{$$ = markAndProcessSymbolListWith(MODULE,OUTPUT, $2, true);}
	| vOUTPUT vSIGNED variable_list ';'		{$$ = markAndProcessSymbolListWith(MODULE,OUTPUT, $3, true);}
	| vOUTPUT variable_list ';'				{$$ = markAndProcessSymbolListWith(MODULE,OUTPUT, $2, false);}
	;

inout_declaration:
	vINOUT net_declaration					{$$ = markAndProcessSymbolListWith(MODULE,INOUT, $2, false);}
	| vINOUT integer_declaration			{$$ = markAndProcessSymbolListWith(MODULE,INOUT, $2, true);}
	| vINOUT vSIGNED variable_list ';'		{$$ = markAndProcessSymbolListWith(MODULE,INOUT, $3, true);}
	| vINOUT variable_list ';'				{$$ = markAndProcessSymbolListWith(MODULE,INOUT, $2, false);}
	;

net_declaration:
	vWIRE vSIGNED variable_list ';'			{$$ = markAndProcessSymbolListWith(MODULE, WIRE, $3, true);}
	| vREG vSIGNED variable_list ';'		{$$ = markAndProcessSymbolListWith(MODULE, REG, $3, true);}
	| vWIRE variable_list ';'				{$$ = markAndProcessSymbolListWith(MODULE, WIRE, $2, false);}
	| vREG variable_list ';'				{$$ = markAndProcessSymbolListWith(MODULE, REG, $2, false);}
	;

integer_declaration:
	vINTEGER integer_type_variable_list ';'	{$$ = markAndProcessSymbolListWith(MODULE,INTEGER, $2, true);}
	;

genvar_declaration:
	vGENVAR integer_type_variable_list ';'	{$$ = markAndProcessSymbolListWith(MODULE,GENVAR, $2, true);}
	;

function_output_variable:
	function_id_and_output_variable	{$$ = newList(VAR_DECLARE_LIST, $1);}
	;

function_id_and_output_variable:
	vSYMBOL_ID					{$$ = newVarDeclare($1, NULL, NULL, NULL, NULL, NULL, yylineno);}
	| '[' expression ':' expression ']' vSYMBOL_ID	{$$ = newVarDeclare($6, $2, $4, NULL, NULL, NULL, yylineno);}
	;

variable_list:
	variable_list ',' variable						{$$ = newList_entry($1, $3);}
	| variable_list '.' variable					{$$ = newList_entry($1, $3);}    //Only for parameter
	| variable										{$$ = newList(VAR_DECLARE_LIST, $1);}
	;

integer_type_variable_list:
	integer_type_variable_list ',' integer_type_variable	{$$ = newList_entry($1, $3);}
	| integer_type_variable									{$$ = newList(VAR_DECLARE_LIST, $1);}
	;

variable:
	vSYMBOL_ID														{$$ = newVarDeclare($1, NULL, NULL, NULL, NULL, NULL, yylineno);}
	| '[' expression ':' expression ']' vSYMBOL_ID										{$$ = newVarDeclare($6, $2, $4, NULL, NULL, NULL, yylineno);}
	| '[' expression ':' expression ']' vSYMBOL_ID '[' expression ':' expression ']'					{$$ = newVarDeclare($6, $2, $4, $8, $10, NULL, yylineno);}
	| '[' expression ':' expression ']' vSYMBOL_ID '[' expression ':' expression ']' '[' expression ':' expression ']'	{$$ = newVarDeclare2D($6, $2, $4, $8, $10,$13,$15, NULL, yylineno);}
	| '[' expression ':' expression ']' vSYMBOL_ID '=' expression								{$$ = newVarDeclare($6, $2, $4, NULL, NULL, $8, yylineno);}
	| vSYMBOL_ID '=' expression												{$$ = newVarDeclare($1, NULL, NULL, NULL, NULL, $3, yylineno);}
	;

integer_type_variable:
	vSYMBOL_ID					{$$ = newIntegerTypeVarDeclare($1, NULL, NULL, NULL, NULL, NULL, yylineno);}
	| vSYMBOL_ID '[' expression ':' expression ']'	{$$ = newIntegerTypeVarDeclare($1, NULL, NULL, $3, $5, NULL, yylineno);}
	| vSYMBOL_ID '=' primary			{$$ = newIntegerTypeVarDeclare($1, NULL, NULL, NULL, NULL, $3, yylineno);} // ONLY FOR PARAMETER
	;

continuous_assign:
	vASSIGN list_of_blocking_assignment ';'	{$$ = $2;}
	;

list_of_blocking_assignment:
	list_of_blocking_assignment ',' blocking_assignment	{$$ = newList_entry($1, $3);}
	| blocking_assignment					{$$ = newList(ASSIGN, $1);}
	;

// 3 Primitive Instances	{$$ = NULL;}
gate_declaration:
	vAND list_of_multiple_inputs_gate_declaration_instance ';'	{$$ = newGate(BITWISE_AND, $2, yylineno);}
	| vNAND	list_of_multiple_inputs_gate_declaration_instance ';'	{$$ = newGate(BITWISE_NAND, $2, yylineno);}
	| vNOR list_of_multiple_inputs_gate_declaration_instance ';'	{$$ = newGate(BITWISE_NOR, $2, yylineno);}
	| vNOT list_of_single_input_gate_declaration_instance ';'	{$$ = newGate(BITWISE_NOT, $2, yylineno);}
	| vOR list_of_multiple_inputs_gate_declaration_instance ';'	{$$ = newGate(BITWISE_OR, $2, yylineno);}
	| vXNOR list_of_multiple_inputs_gate_declaration_instance ';'	{$$ = newGate(BITWISE_XNOR, $2, yylineno);}
	| vXOR list_of_multiple_inputs_gate_declaration_instance ';'	{$$ = newGate(BITWISE_XOR, $2, yylineno);}
	;

list_of_multiple_inputs_gate_declaration_instance:
	list_of_multiple_inputs_gate_declaration_instance ',' multiple_inputs_gate_instance	{$$ = newList_entry($1, $3);}
	| multiple_inputs_gate_instance								{$$ = newList(ONE_GATE_INSTANCE, $1);}
	;

list_of_single_input_gate_declaration_instance:
	list_of_single_input_gate_declaration_instance ',' single_input_gate_instance	{$$ = newList_entry($1, $3);}
	| single_input_gate_instance							{$$ = newList(ONE_GATE_INSTANCE, $1);}
	;

single_input_gate_instance:
	vSYMBOL_ID '(' expression ',' expression ')'	{$$ = newGateInstance($1, $3, $5, NULL, yylineno);}
	| '(' expression ',' expression ')'		{$$ = newGateInstance(NULL, $2, $4, NULL, yylineno);}
	;

multiple_inputs_gate_instance:
	vSYMBOL_ID '(' expression ',' expression ',' list_of_multiple_inputs_gate_connections ')'	{$$ = newMultipleInputsGateInstance($1, $3, $5, $7, yylineno);}
	| '(' expression ',' expression ',' list_of_multiple_inputs_gate_connections ')'	{$$ = newMultipleInputsGateInstance(NULL, $2, $4, $6, yylineno);}
	;

list_of_multiple_inputs_gate_connections: list_of_multiple_inputs_gate_connections ',' expression	{$$ = newList_entry($1, $3);}
	| expression											{$$ = newModuleConnection(NULL, $1, yylineno);}
	;

// 4 MOdule Instantiations
module_instantiation: 
	vSYMBOL_ID list_of_module_instance ';' 							{$$ = newModuleInstance($1, $2, yylineno);}
	;

list_of_module_instance:
	list_of_module_instance ',' module_instance                     {$$ = newList_entry($1, $3);}
	|module_instance                                                {$$ = newList(ONE_MODULE_INSTANCE, $1);}
	;

// 4 Function Instantiations
	function_instantiation: 
	vSYMBOL_ID function_instance 									{$$ = newFunctionInstance($1, $2, yylineno);}
	;

function_instance:
	'(' list_of_function_connections ')'	{$$ = newFunctionNamedInstance($2, NULL, yylineno);}
	;

module_instance:
	vSYMBOL_ID '(' list_of_module_connections ')'						{$$ = newModuleNamedInstance($1, $3, NULL, yylineno);}
	| '#' '(' list_of_module_parameters ')' vSYMBOL_ID '(' list_of_module_connections ')'	{$$ = newModuleNamedInstance($5, $7, $3, yylineno); }
	| vSYMBOL_ID '(' ')'									{$$ = newModuleNamedInstance($1, NULL, NULL, yylineno);}
	| '#' '(' list_of_module_parameters ')' vSYMBOL_ID '(' ')'				{$$ = newModuleNamedInstance($5, NULL, $3, yylineno);}
	;

list_of_function_connections:
	list_of_function_connections ',' module_connection	{$$ = newList_entry($1, $3);}
	| module_connection					{$$ = newfunctionList(MODULE_CONNECT_LIST, $1);}
	;

list_of_module_connections:
	list_of_module_connections ',' module_connection	{$$ = newList_entry($1, $3);}
	| module_connection					{$$ = newList(MODULE_CONNECT_LIST, $1);}
	;

module_connection:
	'.' vSYMBOL_ID '(' expression ')'	{$$ = newModuleConnection($2, $4, yylineno);}
	| expression				{$$ = newModuleConnection(NULL, $1, yylineno);}
	;

list_of_module_parameters:
	list_of_module_parameters ',' module_parameter	{$$ = newList_entry($1, $3);}
	| module_parameter				{$$ = newList(MODULE_PARAMETER_LIST, $1);}
	;

module_parameter:
	'.' vSYMBOL_ID '(' expression ')'	{$$ = newModuleParameter($2, $4, yylineno);}
	| '.' vSYMBOL_ID '(' ')'		{$$ = newModuleParameter($2, NULL, yylineno);}
	| expression				{$$ = newModuleParameter(NULL, $1, yylineno);}
	;

// 5 Behavioral Statements	{$$ = NULL;}
always:
	vALWAYS delay_control statement 					{$$ = newAlways($2, $3, yylineno);}
	| vALWAYS statement									{$$ = newAlways(NULL, $2, yylineno);}

generate:
	vGENERATE generate_item vENDGENERATE	{$$ = $2;}
	;

loop_generate_construct:
	vFOR '(' blocking_assignment ';' expression ';' blocking_assignment ')' generate_block	{$$ = newFor($3, $5, $7, $9, yylineno);}
	; 

if_generate_construct:
	vIF '(' expression ')' generate_block %prec LOWER_THAN_ELSE		{$$ = newIf($3, $5, NULL, yylineno);}
	| vIF '(' expression ')' generate_block vELSE generate_block	{$$ = newIf($3, $5, $7, yylineno);}
	;

case_generate_construct:
	vCASE '(' expression ')' case_generate_item_list vENDCASE			{$$ = newCase($3, $5, yylineno);}
	;

case_generate_item_list:
	case_generate_item_list case_generate_items	{$$ = newList_entry($1, $2);}
	| case_generate_items			{$$ = newList(CASE_LIST, $1);}
	;

case_generate_items:
	expression ':' generate_block	{$$ = newCaseItem($1, $3, yylineno);}
	| vDEFAULT ':' generate_block	{$$ = newDefaultCase($3, yylineno);}
	;

generate_block:
	generate_item										{$$ = $1;}
	| vBEGIN list_of_generate_items vEND				{$$ = $2;}
	| vBEGIN ':' vSYMBOL_ID list_of_generate_items vEND	{free($3); $$ = $4;}
	;

function_statement:
	statement	{$$ = newAlways(NULL, $1, yylineno);}
	;

statement:
	seq_block													{$$ = $1;}
	| c_function ';'											{$$ = $1;}
	| blocking_assignment ';'									{$$ = $1;}
	| non_blocking_assignment ';'								{$$ = $1;}
	| conditional_statement										{$$ = $1;}
	| case_statement											{$$ = $1;}
	| loop_statement											{$$ = $1;}
	| ';'														{$$ = NULL;}
	;

loop_statement:
	vFOR '(' blocking_assignment ';' expression ';' blocking_assignment ')' statement	{$$ = newFor($3, $5, $7, $9, yylineno);}
	| vWHILE '(' expression ')' statement							{$$ = newWhile($3, $5, yylineno);}
	;

case_statement:
	vCASE '(' expression ')' case_item_list vENDCASE			{$$ = newCase($3, $5, yylineno);}
	;

conditional_statement:
	vIF '(' expression ')' statement %prec LOWER_THAN_ELSE	{$$ = newIf($3, $5, NULL, yylineno);}
	| vIF '(' expression ')' statement vELSE statement			{$$ = newIf($3, $5, $7, yylineno);}
	;

blocking_assignment:
	primary '=' expression			{$$ = newBlocking($1, $3, yylineno);}
	| primary '=' vDELAY_ID expression	{$$ = newBlocking($1, $4, yylineno);}
	;

non_blocking_assignment:
	primary voLTE expression		{$$ = newNonBlocking($1, $3, yylineno);}
	| primary voLTE vDELAY_ID expression	{$$ = newNonBlocking($1, $4, yylineno);}
	;


case_item_list:
	case_item_list case_items	{$$ = newList_entry($1, $2);}
	| case_items			{$$ = newList(CASE_LIST, $1);}
	;

case_items:
	expression ':' statement	{$$ = newCaseItem($1, $3, yylineno);}
	| vDEFAULT ':' statement	{$$ = newDefaultCase($3, yylineno);}
	;

seq_block:
	vBEGIN stmt_list vEND			{$$ = $2;}
	| vBEGIN ':' vSYMBOL_ID stmt_list vEND	{free($3); $$ = $4;}
	;

stmt_list:
	stmt_list statement	{$$ = newList_entry($1, $2);}
	| statement		{$$ = newList(BLOCK, $1);}
	;

delay_control:
	'@' '(' event_expression_list ')'	{$$ = $3;}
	| '@' '*'				{$$ = NULL;}
	| '@' '(' '*' ')'			{$$ = NULL;}
	;

// 7 Expressions	{$$ = NULL;}
event_expression_list:
	event_expression_list vOR event_expression	{$$ = newList_entry($1, $3);}
	| event_expression_list ',' event_expression	{$$ = newList_entry($1, $3);}
	| event_expression				{$$ = newList(DELAY_CONTROL, $1);}
	;

event_expression:
	primary			{$$ = $1;}
	| vPOSEDGE vSYMBOL_ID	{$$ = newPosedgeSymbol($2, yylineno);}
	| vNEGEDGE vSYMBOL_ID	{$$ = newNegedgeSymbol($2, yylineno);}
	;

expression:
	primary												{$$ = $1;}
	| '+' expression %prec UADD						{$$ = newUnaryOperation(ADD, $2, yylineno);}
	| '-' expression %prec UMINUS					{$$ = newUnaryOperation(MINUS, $2, yylineno);}
	| '~' expression %prec UNOT						{$$ = newUnaryOperation(BITWISE_NOT, $2, yylineno);}
	| '&' expression %prec UAND						{$$ = newUnaryOperation(BITWISE_AND, $2, yylineno);}
	| '|' expression %prec UOR						{$$ = newUnaryOperation(BITWISE_OR, $2, yylineno);}
	| voNAND expression %prec UNAND					{$$ = newUnaryOperation(BITWISE_NAND, $2, yylineno);}
	| voNOR expression %prec UNOR					{$$ = newUnaryOperation(BITWISE_NOR, $2, yylineno);}
	| voXNOR  expression %prec UXNOR				{$$ = newUnaryOperation(BITWISE_XNOR, $2, yylineno);}
	| '!' expression %prec ULNOT					{$$ = newUnaryOperation(LOGICAL_NOT, $2, yylineno);}
	| '^' expression %prec UXOR						{$$ = newUnaryOperation(BITWISE_XOR, $2, yylineno);}
	| vCLOG2 '(' expression ')'						{$$ = newUnaryOperation(CLOG2, $3, yylineno);}
	| voUNSIGNED '(' expression ')'					{$$ = newUnaryOperation(UNSIGNED, $3, yylineno);}
	| voSIGNED '(' expression ')'					{$$ = newUnaryOperation(SIGNED, $3, yylineno);}
	| expression '^' expression						{$$ = newBinaryOperation(BITWISE_XOR, $1, $3, yylineno);}
	| expression voPOWER expression					{$$ = newBinaryOperation(POWER,$1, $3, yylineno);}
	| expression '*' expression						{$$ = newBinaryOperation(MULTIPLY, $1, $3, yylineno);}
	| expression '/' expression						{$$ = newBinaryOperation(DIVIDE, $1, $3, yylineno);}
	| expression '%' expression						{$$ = newBinaryOperation(MODULO, $1, $3, yylineno);}
	| expression '+' expression						{$$ = newBinaryOperation(ADD, $1, $3, yylineno);}
	| expression '-' expression						{$$ = newBinaryOperation(MINUS, $1, $3, yylineno);}
	| expression '&' expression						{$$ = newBinaryOperation(BITWISE_AND, $1, $3, yylineno);}
	| expression '|' expression						{$$ = newBinaryOperation(BITWISE_OR, $1, $3, yylineno);}
	| expression voNAND expression					{$$ = newBinaryOperation(BITWISE_NAND, $1, $3, yylineno);}
	| expression voNOR expression					{$$ = newBinaryOperation(BITWISE_NOR, $1, $3, yylineno);}
	| expression voXNOR expression					{$$ = newBinaryOperation(BITWISE_XNOR, $1, $3, yylineno);}
	| expression '<' expression						{$$ = newBinaryOperation(LT, $1, $3, yylineno);}
	| expression '>' expression						{$$ = newBinaryOperation(GT, $1, $3, yylineno);}
	| expression voSRIGHT expression				{$$ = newBinaryOperation(SR, $1, $3, yylineno);}
	| expression voASRIGHT expression				{$$ = newBinaryOperation(ASR, $1, $3, yylineno);}
	| expression voSLEFT expression					{$$ = newBinaryOperation(SL, $1, $3, yylineno);}
	| expression voEQUAL expression					{$$ = newBinaryOperation(LOGICAL_EQUAL, $1, $3, yylineno);}
	| expression voNOTEQUAL expression				{$$ = newBinaryOperation(NOT_EQUAL, $1, $3, yylineno);}
	| expression voLTE expression					{$$ = newBinaryOperation(LTE, $1, $3, yylineno);}
	| expression voGTE expression					{$$ = newBinaryOperation(GTE, $1, $3, yylineno);}
	| expression voCASEEQUAL expression				{$$ = newBinaryOperation(CASE_EQUAL, $1, $3, yylineno);}
	| expression voCASENOTEQUAL expression			{$$ = newBinaryOperation(CASE_NOT_EQUAL, $1, $3, yylineno);}
	| expression voOROR expression					{$$ = newBinaryOperation(LOGICAL_OR, $1, $3, yylineno);}
	| expression voANDAND expression				{$$ = newBinaryOperation(LOGICAL_AND, $1, $3, yylineno);}
	| expression '?' expression ':' expression		{$$ = newIfQuestion($1, $3, $5, yylineno);}
	| function_instantiation						{$$ = $1;}
	| '(' expression ')'							{$$ = $2;}
	| '{' expression '{' expression_list '}' '}'	{$$ = newListReplicate( $2, $4 ); }
	| c_function									{$$ = $1;}
	;

primary:
	vNUMBER													{$$ = newNumberNode($1, yylineno);}
	| vSYMBOL_ID											{$$ = newSymbolNode($1, yylineno);}
	| vSYMBOL_ID '[' expression ']'							{$$ = newArrayRef($1, $3, yylineno);}
	| vSYMBOL_ID '[' expression ']' '[' expression ']'		{$$ = newArrayRef2D($1, $3, $6, yylineno);}
	| vSYMBOL_ID '[' expression vPLUS_COLON expression ']'	{$$ = newPlusColonRangeRef($1, $3, $5, yylineno);}
	| vSYMBOL_ID '[' expression vMINUS_COLON expression ']'	{$$ = newMinusColonRangeRef($1, $3, $5, yylineno);}
	| vSYMBOL_ID '[' expression ':' expression ']'			{$$ = newRangeRef($1, $3, $5, yylineno);}
	| vSYMBOL_ID '[' expression ':' expression ']' '[' expression ':' expression ']'	{$$ = newRangeRef2D($1, $3, $5, $8, $10, yylineno);}
	| '{' expression_list '}'								{$$ = $2; ($2)->types.concat.num_bit_strings = -1;}
	;
expression_list:
	expression_list ',' expression	{$$ = newList_entry($1, $3); /* note this will be in order lsb = greatest to msb = 0 in the node child list */}
	| expression					{$$ = newList(CONCATENATE, $1);}
	;

 c_function:
	vCFUNC '(' c_function_expression_list ')'	{$$ = NULL;}
	| vCFUNC '(' ')'							{$$ = NULL;}
	| vCFUNC									{$$ = NULL;}
	;

 c_function_expression_list:
	expression ',' c_function_expression_list	{$$ = free_whole_tree($1);}
	| expression								{$$ = free_whole_tree($1);}
	;

%%
