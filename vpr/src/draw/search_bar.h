#ifndef SEARCH_BAR_H
#define SEARCH_BAR_H

#include "easygl_constants.h"
#include "graphics.h"
#include "draw_global.h"

#include "ezgl/point.hpp"
#include "ezgl/application.hpp"
#include "ezgl/graphics.hpp"
#include "draw_color.h"


void search_and_highlight(GtkWidget *widget, ezgl::application *app);
bool highlight_rr_nodes(int hit_node);
void auto_zoom_rr_node(int rr_node_id);
void highlight_blocks(ClusterBlockId clb_index);
void highlight_nets(ClusterNetId net_id);
void highlight_nets(std::string net_name);
void highlight_blocks(std::string block_name);

#endif /* SEARCH_BAR_H */

