/* Standard libraries */
#include <stdlib.h>
#include <string.h>

/* Odin_II libraries */
#include "odin_globals.h"
#include "odin_types.h"
#include "ast_util.h"
#include "ast_elaborate.h"
#include "parse_making_ast.h"
#include "odin_util.h"
#include "vtr_memory.h"
#include "vtr_util.h"

/* This files header */
#include "ast_loop_unroll.h"

void update_module_instantiations(ast_node_t *ast_module, ast_node_t ****new_instances, ast_node_t ***removed_instances, int *num_unrolled, int *num_original, int *num_removed);
long find_module_instance(ast_node_t *ast_module, char *instance_name, ast_node_t ***instances, int *num_instances);

/*
 *  (function: unroll_loops)
 */
void unroll_loops(ast_node_t **ast_module, STRING_CACHE_LIST *local_string_cache_list)
{
	ast_node_t **removed_instances = NULL;
	int num_removed = 0;

	ast_node_t* module = for_preprocessor((*ast_module), (*ast_module), local_string_cache_list, &removed_instances, &num_removed);

	for (int i = 0; i < num_removed; i++)
	{
		free_whole_tree(removed_instances[i]);
	}
	vtr::free(removed_instances);

	if(module != *ast_module)
		free_whole_tree(*ast_module);
	*ast_module = module;
}

void update_module_instantiations(ast_node_t *ast_module, ast_node_t ****new_instances, ast_node_t ***removed_instances, int *num_unrolled, int *num_original, int *num_removed)
{
	long idx;
	ast_node_t ***module_instantiations = &(ast_module->types.module.module_instantiations_instance);
	int *module_instantiations_size = &(ast_module->types.module.size_module_instantiations);
	for (long i = 0; i < (*num_original); i++)
	{
		char *instance_name = make_full_name_w_o_array_ref(ast_module->children[0]->types.identifier,
				(*new_instances)[i][0]->children[0]->types.identifier,
				(*new_instances)[i][0]->children[1]->children[0]->types.identifier);
				
		if ((idx = find_module_instance(ast_module, instance_name, module_instantiations, module_instantiations_size)) != -1)
		{
			(*removed_instances) = (ast_node_t **)vtr::realloc((*removed_instances), sizeof(ast_node_t*)*((*num_removed)+1));
			(*removed_instances)[*num_removed] = ast_node_deep_copy((*module_instantiations)[idx]);
			(*num_removed)++;

			(*module_instantiations) = expand_node_list_at(*module_instantiations, *module_instantiations_size, (*num_unrolled) - 1, idx + 1);
			(*module_instantiations_size) = (*module_instantiations_size) + ((*num_unrolled) - 1);

			/* grab original instance */
			char *original_instance_name = (*new_instances)[i][0]->children[0]->types.identifier;

			long sc_spot_2 = sc_lookup_string(module_names_to_idx, original_instance_name);
			oassert(sc_spot_2 > -1);

			/* free the "template" instance */
			free_whole_tree((*new_instances)[i][0]);

			for (long j = 1; j <= (*num_unrolled); j++)
			{
				(*module_instantiations)[(idx+j)-1] = (*new_instances)[i][j];

				/* add new instance to module_names_to_idx */
				char *new_instance_name = make_full_ref_name(ast_module->children[0]->types.identifier,
					(*new_instances)[i][j]->children[0]->types.identifier,
					(*new_instances)[i][j]->children[1]->children[0]->types.identifier,
					NULL, -1);

				long sc_spot = sc_add_string(module_names_to_idx, new_instance_name);
				oassert(sc_spot != -1);
				module_names_to_idx->data[sc_spot] = (void *)ast_node_deep_copy((ast_node_t*)module_names_to_idx->data[sc_spot_2]);

				ast_modules = (ast_node_t **)vtr::realloc(ast_modules, sizeof(ast_modules)*(sc_spot+1));
				ast_modules[sc_spot] = (ast_node_t *)module_names_to_idx->data[sc_spot];
				ast_modules[sc_spot]->types.module.index = sc_spot;

				vtr::free(new_instance_name);
			}		
		}
		else if ((*num_removed) > 0 && 
			(idx = find_module_instance(ast_module, instance_name, removed_instances, num_removed)) != -1)
		{
			(*module_instantiations) = expand_node_list_at(*module_instantiations, *module_instantiations_size, (*num_unrolled), idx + 1);
			(*module_instantiations_size) = (*module_instantiations_size) + ((*num_unrolled));

			/* grab original instance */
			char *original_instance_name = (*new_instances)[i][0]->children[0]->types.identifier;

			long sc_spot_2 = sc_lookup_string(module_names_to_idx, original_instance_name);
			oassert(sc_spot_2 > -1);

			/* free the "template" instance */
			free_whole_tree((*new_instances)[i][0]);

			for (long j = 1; j <= (*num_unrolled); j++)
			{
				(*module_instantiations)[(idx+j)] = (*new_instances)[i][j];

				/* add new instance to module_names_to_idx */
				char *new_instance_name = make_full_ref_name(ast_module->children[0]->types.identifier,
					(*new_instances)[i][j]->children[0]->types.identifier,
					(*new_instances)[i][j]->children[1]->children[0]->types.identifier,
					NULL, -1);

				long sc_spot = sc_add_string(module_names_to_idx, new_instance_name);
				oassert(sc_spot != -1);
				module_names_to_idx->data[sc_spot] = ast_node_deep_copy((ast_node_t*)module_names_to_idx->data[sc_spot_2]);

				ast_modules = (ast_node_t **)vtr::realloc(ast_modules, sizeof(ast_modules)*(sc_spot+1));
				ast_modules[sc_spot] = (ast_node_t *)module_names_to_idx->data[sc_spot];
				ast_modules[sc_spot]->types.module.index = sc_spot;

				vtr::free(new_instance_name);
			}
		}
		else 
		{
			error_message(NETLIST_ERROR, ast_module->line_number, ast_module->file_number,
						"Can't find module name %s\n", instance_name);
		}

		vtr::free(instance_name);
	}
	
}

/*
*	(function: find_module_instance)
*/
long find_module_instance(ast_node_t *ast_module, char *instance_name, ast_node_t ***instances, int *num_instances)
{
	long i;
	for (i = 0; i < *num_instances; i++)
	{
		ast_node_t *module_instance = (*instances)[i];
		char *original_name = make_full_ref_name(ast_module->children[0]->types.identifier,
				module_instance->children[0]->types.identifier,
				module_instance->children[1]->children[0]->types.identifier,
				NULL, -1);
		
		int result = strcmp(instance_name, original_name);
		vtr::free(original_name);

		if(result == 0)
		{	
			return i;
		}
	}

	return -1;
}

/*
 *  (function: for_preprocessor)
 */
ast_node_t* for_preprocessor(ast_node_t *ast_module, ast_node_t* node, STRING_CACHE_LIST *local_string_cache_list, ast_node_t ***removed_instances, int *num_removed)
{
	if(!node)
		return nullptr;
	/* If this is a for node, something has gone wrong */
	oassert(!is_for_node(node));
	
	/* If this node has for loops as children, replace them */
	bool for_loops = false;
	for(int i=0; i<node->num_children && !for_loops; i++){
		for_loops = is_for_node(node->children[i]);
	}

	ast_node_t* new_node = NULL;
	if(for_loops)
	{
		new_node = replace_fors(ast_module, node, local_string_cache_list, removed_instances, num_removed);
	}
	else
	{
		new_node = node;
	}
	
	if(new_node)
	{
		/* Run this function recursively on the children */
		for(int i=0; i<new_node->num_children; i++){
			ast_node_t* new_child = for_preprocessor(ast_module, new_node->children[i], local_string_cache_list, removed_instances, num_removed);

			/* Cleanup replaced child */
			if(new_node->children[i] != new_child){
				free_whole_tree(new_node->children[i]);
				new_node->children[i] = new_child;
			}
		}
	}
	
	return new_node;
}

/*
 *  (function: replace_fors)
 */
ast_node_t* replace_fors(ast_node_t *ast_module, ast_node_t* node, STRING_CACHE_LIST *local_string_cache_list, ast_node_t ***removed_instances, int *num_removed)
{
	oassert(!is_for_node(node));
	oassert(node != nullptr);

	ast_node_t* new_node = ast_node_deep_copy(node);
	if(!new_node)
		return nullptr;

	/* process children one at a time */
	for(int i = 0; i < new_node->num_children; i++)
	{
		/* unroll `for` children */
		if(is_for_node(new_node->children[i]))
		{
			ast_node_t ***unrolled_module_instances = NULL;
			int num_unrolled_module_instances = 0;
			int num_original_module_instances = 0;

			ast_node_t* unrolled_for = resolve_for(ast_module, new_node->children[i], local_string_cache_list, &unrolled_module_instances, &num_unrolled_module_instances, &num_original_module_instances);
			oassert(unrolled_for != nullptr);
			free_whole_tree(new_node->children[i]);
			new_node->children[i] = unrolled_for;

			/* update module instantiations in this loop */
			if (unrolled_module_instances)
			{
				update_module_instantiations(ast_module, &unrolled_module_instances, removed_instances, &num_unrolled_module_instances, &num_original_module_instances, num_removed);
				
				for (int j = 0; j < num_original_module_instances; j++)
				{
					vtr::free(unrolled_module_instances[j]);
				}
				vtr::free(unrolled_module_instances);

				num_unrolled_module_instances = 0;
				num_original_module_instances = 0;
			}
		}
	}
	return new_node;
}

/*
 *  (function: resolve_for)
 */
ast_node_t* resolve_for(ast_node_t *ast_module, ast_node_t* node, STRING_CACHE_LIST *local_string_cache_list, ast_node_t ****instances, int *num_unrolled, int *num_original)
{
	oassert(is_for_node(node));
	oassert(node != nullptr);
	ast_node_t* body_parent = nullptr;

	ast_node_t* pre  = node->children[0];
	ast_node_t* cond = node->children[1];
	ast_node_t* post = node->children[2];
	ast_node_t* body = node->children[3];
	
	ast_node_t* value = 0;
	if(resolve_pre_condition(pre, &value))
	{
		error_message(PARSE_ERROR, pre->line_number, pre->file_number, "%s", "Unsupported pre-condition node in for loop");
	}

	int error_code = 0;
	condition_function cond_func = resolve_condition(cond, pre->children[0], &error_code);
	if(error_code)
	{
		error_message(PARSE_ERROR, cond->line_number, cond->file_number, "%s", "Unsupported condition node in for loop");
	}

	post_condition_function post_func = resolve_post_condition(post, pre->children[0], &error_code);
	if(error_code)
	{
		error_message(PARSE_ERROR, post->line_number, post->file_number, "%s", "Unsupported post-condition node in for loop");
	}

	bool dup_body = cond_func(value->types.vnumber->get_value());
	while(dup_body)
	{
		ast_node_t* new_body = dup_and_fill_body(ast_module, body, pre, &value, &error_code, instances, num_unrolled, num_original, false);
		if(error_code)
		{
			error_message(PARSE_ERROR, pre->line_number, pre->file_number, "%s", "Unsupported pre-condition node in for loop");
		}

		VNumber *temp_vnum = value->types.vnumber;
		value->types.vnumber = new VNumber(post_func(temp_vnum->get_value()));
		delete temp_vnum;
		
		body_parent = body_parent ? newList_entry(body_parent, new_body) : newList(BLOCK, new_body);
		
		dup_body = cond_func(value->types.vnumber->get_value());

		if (*instances)
		{
			(*num_unrolled)++;
		}
	}

	free_whole_tree(value);
	body_parent = reduce_expressions(body_parent, local_string_cache_list, NULL, 0, false);
	return body_parent;
}

/*
 *  (function: resolve_pre_condition)
 *  return 0 if the first value of the variable set
 *  in the pre condition of a `for` node has been put in location 
 *  pointed to by the number pointer.
 *
 *  return a non-zero number on failure.
 *  define failure constants in header.
 */
int resolve_pre_condition(ast_node_t* node, ast_node_t** number_node)
{
	/* Add new for loop support here. Keep current work in the TODO
	 * Currently supporting:
	 *     for(VAR = NUM; ...; ...) ...
	 * TODO:
	 *     for(VAR = function(PARAMS...); ...; ...) ...
	 */
	/* IMPORTANT: if support for more complex continue conditions is added, update this inline function. */
	if(is_unsupported_pre(node))
	{
		return UNSUPPORTED_PRE_CONDITION_NODE;
	}
	if (*number_node) free_whole_tree(*number_node);
	*number_node = ast_node_deep_copy(node->children[1]);
	return 0;
}

/** IMPORTANT: as support for more complex continue conditions is added, update this function. 
 *  (function: is_unsupported_condition)
 *  returns true if, given the supplied symbol, the node can be simplifed 
 *  to true or false if the symbol is replaced with some value.
 */
bool is_unsupported_condition(ast_node_t* node, ast_node_t* symbol){
	bool invalid_inequality = ( node->type != BINARY_OPERATION ||
			!(  node->types.operation.op == LT ||
				node->types.operation.op == GT ||
				node->types.operation.op == LOGICAL_EQUAL ||
				node->types.operation.op == NOT_EQUAL ||
				node->types.operation.op == LTE ||
				node->types.operation.op == GTE) ||
			node->num_children != 2 ||
			node->children[1] == nullptr ||
			!(  node->children[1]->type == NUMBERS ||
				node->children[1]->type == IDENTIFIERS ) ||
			node->children[0] == nullptr ||
			!(  node->children[0]->type == NUMBERS ||
				node->children[0]->type == IDENTIFIERS ));

	bool invalid_logical_concatenation = ( node->type != BINARY_OPERATION ||
			!(  node->types.operation.op == LOGICAL_OR ||
				node->types.operation.op == LOGICAL_AND) ||
			node->num_children != 2 ||
			node->children[1] == nullptr ||
			is_unsupported_condition(node->children[1], symbol) ||
			node->children[0] == nullptr ||
			is_unsupported_condition(node->children[0], symbol));

	bool invalid_negation = ( node->type != UNARY_OPERATION ||
			node->types.operation.op != LOGICAL_NOT ||
			node->num_children != 1 ||
			node->children[0] == nullptr ||
			is_unsupported_condition(node->children[0], symbol));

	bool contains_unknown_symbols = !(invalid_inequality) && (
			(   node->children[0]->type == IDENTIFIERS &&
				strcmp(node->children[0]->types.identifier, symbol->types.identifier)) ||
			(   node->children[1]->type == IDENTIFIERS &&
				strcmp(node->children[1]->types.identifier, symbol->types.identifier)));

	return ((invalid_inequality || contains_unknown_symbols) && invalid_logical_concatenation && invalid_negation);
}

/*
 *  (function: resolve_condition)
 *  return a lambda which tests the loop condition for a given value
 */
condition_function resolve_condition(ast_node_t* node, ast_node_t* symbol, int* error_code)
{
	/* Add new for loop support here. Keep current work in the TODO
	 * Currently supporting:
	 *     for(...; VAR {<, >, ==, !=, <=, >=} NUM; ...) ...
	 *     for(...; CONDITION_A {&&, ||} CONDITION_B;...) ...
	 *     for(...; !(CONDITION);...) ...
	 * TODO:
	 *     for(...; {EXPRESSION_OF_VAR, NUM} {<, >, ==, !=, <=, >=} {EXPRESSION_OF_VAR, NUM}; ...) ...
	 */
	/* IMPORTANT: if support for more complex continue conditions is added, update this inline function. */
	if(is_unsupported_condition(node, symbol))
	{
		*error_code = UNSUPPORTED_CONDITION_NODE;
		return nullptr;
	}
	*error_code = 0;
	/* Resursive calls need to report errors before returning a lambda */
	condition_function left = nullptr;
	condition_function right = nullptr;
	condition_function inner = nullptr;
	switch(node->types.operation.op){
		case LOGICAL_OR:
			left = resolve_condition(node->children[0], symbol, error_code);
			if(*error_code)
				return nullptr;
			right = resolve_condition(node->children[1], symbol, error_code);
			if(*error_code)
				return nullptr;
			return [=](long value) {
				return (left(value) || right(value));
			};
		case LOGICAL_AND:
			left = resolve_condition(node->children[0], symbol, error_code);
			if(*error_code)
				return nullptr;
			right = resolve_condition(node->children[1], symbol, error_code);
			if(*error_code)
				return nullptr;
			return [=](long value) {
				return (left(value) && right(value));
			};
		case LOGICAL_NOT:
			inner = resolve_condition(node->children[0], symbol, error_code);
			if(*error_code) 
				return nullptr;
			return [=](long value) {
				bool inner_true = inner(value);
				return !inner_true;
			};
		default:
			break;
	}
	/* Non-recursive calls can type check in the lambda to save copy/paste */
	return [=](long value) {
		switch(node->types.operation.op){
			case LT:
				return value <  node->children[1]->types.vnumber->get_value();
			case GT:
				return value >  node->children[1]->types.vnumber->get_value();
			case NOT_EQUAL:
				return value != node->children[1]->types.vnumber->get_value();
			case LOGICAL_EQUAL:
				return value == node->children[1]->types.vnumber->get_value();
			case LTE:
				return value <= node->children[1]->types.vnumber->get_value();
			case GTE:
				return value >= node->children[1]->types.vnumber->get_value(); 
			default:
			   return false;
	   }
	};
}


/* IMPORTANT: as support for more complex post conditions is added, update this function. 
 * (function: is_unsupported_post)
 * returns true if the post condition blocking assignment is more complex than
 * can currently be unrolled statically
 */
bool is_unsupported_post(ast_node_t* node, ast_node_t* symbol){
	return  (node == nullptr ||
			node->type != BINARY_OPERATION ||
			!(  node->types.operation.op == ADD ||
				node->types.operation.op == MINUS ||
				node->types.operation.op == MULTIPLY ||
				node->types.operation.op == DIVIDE) ||
			node->num_children != 2 ||
			node->children[1] == nullptr ||
			!(  (   node->children[1]->type == IDENTIFIERS &&
					!strcmp(node->children[1]->types.identifier, symbol->types.identifier))||
				node->children[1]->type == NUMBERS ||
				!is_unsupported_post(node->children[0], symbol)) ||
			node->children[0] == nullptr ||
			!(  (   node->children[0]->type == IDENTIFIERS &&
					!strcmp(node->children[0]->types.identifier, symbol->types.identifier))||
				node->children[0]->type == NUMBERS ||
				!is_unsupported_post(node->children[0], symbol)));
}

post_condition_function resolve_binary_operation(ast_node_t* node)
{
	if(node->type == NUMBERS){
		return [=](long value){
			/* 
			 * this lambda triggers a warning for unused variable unless
			 * we use value to generate a 0
			 */
			return node->types.vnumber->get_value() + (value - value);
		};
	} else if (node->type == IDENTIFIERS) {
		return [=](long value){
			return value;
		};
	} else {
		return [=](long value) {
			post_condition_function left_func = resolve_binary_operation(node->children[0]);
			post_condition_function right_func = resolve_binary_operation(node->children[1]);
			switch(node->types.operation.op){
				case ADD:
					return left_func(value) + right_func(value);
				case MINUS:
					return left_func(value) - right_func(value);
				case MULTIPLY:
					return left_func(value) * right_func(value);
				case DIVIDE:
					return left_func(value) / right_func(value);
				default:
					return 0x0L;
			}
		};
	}
}

/*
 *  (function: resolve_post_condition)
 *  return a lambda which gives the next value
 *  of the loop variable given the current value
 *  of the loop variable
 */
post_condition_function resolve_post_condition(ast_node_t* assignment, ast_node_t* symbol, int* error_code)
{
	/* Add new for loop support here. Keep current work in the TODO
	 * Given iteration t, and VAR[t] is the value of VAR at iteration t,
	 * VAR[0] is init, EXPRESSION_OF_VAR[t] is the value of the post 
	 * expression evaluated at iteration t, and VAR[t+1] is the 
	 * value of VAR after the current iteration:
	 *     Currently supporting:
	 *         for(...; ...; VAR = VAR {+, -, *, /} NUM) ...
	 *         for(...; ...; VAR[t+1] = EXPRESSION_OF_VAR[t])
	 *     TODO:
	 *         for(...; ...; VAR[t+1] = function_call(VAR[t]))
	 */
	ast_node_t* node = nullptr;
	/* Check that the post condition assignment node is a valid assignment */
	if( assignment != nullptr &&
		assignment->type == BLOCKING_STATEMENT &&
		assignment->num_children == 2 &&
		assignment->children[0] != nullptr &&
		assignment->children[1] != nullptr)
	{
		node = assignment->children[1];
	}
	/* IMPORTANT: If support for more complex post conditions is added, update this inline function */
	if(is_unsupported_post(node, symbol)) 
	{
		*error_code = UNSUPPORTED_POST_CONDITION_NODE;
		return nullptr;
	}
	*error_code = 0;
	return resolve_binary_operation(node);
}

ast_node_t* replace_named_module(ast_node_t* module, ast_node_t** value)
{
	ast_node_t* copy = ast_node_deep_copy(module);

	oassert( value  && "Value node reference is NULL");
	oassert( *value && "Value node is NULL");
	oassert( (*value)->type == NUMBERS  && "Value node type is not a NUMBER");

	long int val = (*value)->types.vnumber->get_value();
	std::string concat_string(copy->children[0]->types.identifier);
	concat_string = concat_string + "[" + std::to_string(val) + "]";

	vtr::free(copy->children[0]->types.identifier);
	copy->children[0]->types.identifier = vtr::strdup(concat_string.c_str());

	free_whole_tree(module);
	return copy;
}

ast_node_t* dup_and_fill_body(ast_node_t *ast_module, ast_node_t* body, ast_node_t* pre, ast_node_t** value, int* error_code, ast_node_t ****instances, int *num_unrolled, int *num_original, bool is_nested)
{
	ast_node_t* copy = ast_node_deep_copy(body);
	for(long i = 0; i<copy->num_children; i++)
	{
		ast_node_t* child = copy->children[i];
		if (child) 
		{
			if(child->type == IDENTIFIERS)
			{
				if(!strcmp(child->types.identifier, pre->children[0]->types.identifier))
				{
					ast_node_t* new_num = ast_node_copy(*value);
					child = free_whole_tree(child);
					copy->children[i] = new_num;
				}
			} 
			else if(child->type == MODULE_INSTANCE && child->children[0]->type != MODULE_INSTANCE)
			{
				if (!is_nested)
				{
					long idx = -1;

					/* if this is the first iteration */
					if ((*value)->types.vnumber->get_value() == pre->children[1]->types.vnumber->get_value()) 
					{
						/* add this instance to the table */
						if (!(*instances))
						{
							(*instances) = (ast_node_t***)vtr::malloc(sizeof(ast_node_t**));
						}
						else{
							(*instances) = (ast_node_t***)vtr::realloc((*instances), sizeof(ast_node_t**)*(*num_original+1));
						}

						(*instances)[(*num_original)] = (ast_node_t **) vtr::malloc(sizeof(ast_node_t*));
						(*instances)[(*num_original)][0] = ast_node_deep_copy(child);
						idx = (*num_original);
						(*num_original)++;
					}
					else
					{
						long j;
						/* find the correct instance in the table */
						bool found = false;
						char *instance_name = make_full_ref_name(ast_module->children[0]->types.identifier,
								child->children[0]->types.identifier,
								child->children[1]->children[0]->types.identifier,
								NULL, -1);

						char *temp_instance_name = NULL;

						for (j = 0; !found && j < (*num_original); j++)
						{
							// make full ref name of this original 
							temp_instance_name = make_full_ref_name(ast_module->children[0]->types.identifier,
								(*instances)[j][0]->children[0]->types.identifier,
								(*instances)[j][0]->children[1]->children[0]->types.identifier,
								NULL, -1);

							// if they match, found = true and this_instance = j
							if (!strcmp(instance_name, temp_instance_name))
							{
								found = true;
								idx = j;
							}

							vtr::free(temp_instance_name);
						}
						oassert(found);
						vtr::free(instance_name);
					}

					/* give this unrolled instance a unique name */
					copy->children[i]->children[1] = replace_named_module(child->children[1], value);
					oassert(copy->children[i]->children[1]);

					/* find and replace iteration symbol for port connections and parameters */
					ast_node_t *named_instance = child->children[1];
					copy->children[i]->children[1] = dup_and_fill_body(ast_module, named_instance, pre, value, error_code, instances, num_unrolled, num_original, is_nested);
					free_whole_tree(named_instance);

					/* then add it to the table of unrolled instances */
					(*instances)[idx] = (ast_node_t**)vtr::realloc((*instances)[idx], sizeof(ast_node_t*)*((*num_unrolled)+2));
					(*instances)[idx][(*num_unrolled)+1] = ast_node_deep_copy(copy->children[i]);
				}
				else
				{
					/* give this unrolled instance a unique name */
					copy->children[i]->children[1] = replace_named_module(child->children[1], value);
					oassert(copy->children[i]->children[1]);

					/* find and replace iteration symbol for port connections and parameters */
					ast_node_t *named_instance = child->children[1];
					copy->children[i]->children[1] = dup_and_fill_body(ast_module, named_instance, pre, value, error_code, instances, num_unrolled, num_original, is_nested);
					free_whole_tree(named_instance);
				}
			} 

			if(child && child->num_children > 0)
			{
				if (child->type == MODULE_INSTANCE && child->children[0]->type != MODULE_INSTANCE)
				{
					/* already been unrolled; do nothing */
				}
				else
				{
					for (int j = 0; j < copy->children[i]->num_children; j++)
					{
						if (copy->children[i]->children[j] != child->children[j]) free_whole_tree(copy->children[i]->children[j]);
					}
					if (!is_for_node(child))
					{
						copy->children[i] = dup_and_fill_body(ast_module, child, pre, value, error_code, instances, num_unrolled, num_original, is_nested);
						free_whole_tree(child);
					}
					else
					{
						// go in and update this iteration symbol, instance names if applicable
						copy->children[i] = dup_and_fill_body(ast_module, child, pre, value, error_code, instances, num_unrolled, num_original, true);
						free_whole_tree(child);
					}
				}
			}
		}
	}
	return copy;
}
