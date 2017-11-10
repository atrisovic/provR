# Copyright (C) 2017 Harvard University, Mount Holyoke College
#
# This file is part of ProvR.
#
# ProvR is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# ProvR is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ProvR; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# This package was forked from <https://github.com/End-to-end-provenance/RDataTracker>
#
# Contact: Matthew Lau <matthewklau@fas.harvard.edu>

# .ddg.proc2proc creates a control flow edge from the preceding procedure node to
# the current procedure node.
.ddg.proc2proc <- function() {
    ddg.pnum <- .global.get("ddg.pnum")
    if (ddg.pnum > 1) {
        # Record in edges table
        etype <- "cf"
        node1 <- paste("p", ddg.pnum - 1, sep = "")
        node2 <- paste("p", ddg.pnum, sep = "")
        .ddg.record.edge(etype, node1, node2)
        if (.global.get("ddg.debug.lib")) {
            pname1 <- .proc.name(ddg.pnum - 1)
            pname2 <- .proc.name(ddg.pnum)
            print(paste("proc2proc: ", pname1, " ", pname2))
            print(paste("CF ", node1, " ", node2, sep = ""))
        }
    }
    invisible()
}

# .ddg.data2proc creates a data flow edge from a data node to a procedure node.
# dname - data node name.  dscope - data node scope.  pname - procedure node
# name.
.ddg.data2proc <- function(dname, dscope, pname) {
    # Get data & procedure numbers.
    dn <- .ddg.data.number(dname, dscope)
    pn <- .proc.number(pname)
    # Record in edges table
    etype <- "df.in"
    node1 <- paste("d", dn, sep = "")
    node2 <- paste("p", pn, sep = "")
    .ddg.record.edge(etype, node1, node2)
    if (.global.get("ddg.debug.lib")) {
        print(paste("data2proc: ", dname, " ", pname, sep = ""))
        print(paste("DF ", node1, " ", node2, sep = ""))
    }
    invisible()
}

# .ddg.proc2data creates a data flow edge from a procedure node to a data node.
# pname - procedure node name.  dname - data node name.  dscope (optional) - data
# node scope.  ret.value (optional) - if true it means we are linking to a
# return value. In this case, we need to be sure that there is not already a
# return value linked.  This is necessary to manage recursive functions
# correctly.
.ddg.proc2data <- function(pname, dname, dscope = NULL, ret.value = FALSE) {
    # Get data & procedure numbers.
    dn <- .ddg.data.number(dname, dscope)
    # attach data node to the last procedure node if pname is NULL.
    if (is.null(pname) || startsWith(pname, ".ddg.") || startsWith(pname, "ddg"))
        pn <- .last.proc.number() else pn <- .proc.number(pname, ret.value)
    # Create data flow edge from procedure node to data node.
    if (dn != 0 && pn != 0) {
        # Record in edges table
        etype <- "df.out"
        node1 <- paste("p", pn, sep = "")
        node2 <- paste("d", dn, sep = "")
        .ddg.record.edge(etype, node1, node2)
        # Record that the function is linked to a return value.  This is necessary for
        # recursive functions to get linked to their return values correctly.
        if (ret.value) {
            ddg.proc.nodes <- .global.get("ddg.proc.nodes")
            ddg.proc.nodes$ddg.ret.linked[pn] <- TRUE
            .global.set("ddg.proc.nodes", ddg.proc.nodes)
        }
        if (.global.get("ddg.debug.lib")) {
            print(paste("proc2data: ", pname, " ", dname, sep = ""))
            print(paste("DF ", node1, " ", node2, sep = ""))
        }
    }
    invisible()
}

# .ddg.lastproc2data creates a data flow edge from the last procedure node to a
# data node.
# dname - data node name.  all (optional) - whether all nodes should be
# considered (TRUE) or only procedure nodes (FALSE).  dscope - the scope in which
# dname should be looked up
.ddg.lastproc2data <- function(dname, all = TRUE, dscope = NULL) {
    # Get data & procedure numbers.
    dn <- .ddg.data.number(dname, dscope)
    pn <- if (all)
        .global.get("ddg.pnum") else .last.proc.number()
    # Record in edges table
    etype <- "df.out"
    node1 <- paste("p", pn, sep = "")
    node2 <- paste("d", dn, sep = "")
    .ddg.record.edge(etype, node1, node2)
    if (.global.get("ddg.debug.lib")) {
        print(paste("lastproc2data:", dname))
        print(paste("DF ", node1, " ", node2, sep = ""))
    }
}

# .ddg.record.edge records a control flow edge or a data flow edge in the edges
# table.
# etype - type of edge node1 - name of first node node1 - name of second node
.ddg.record.edge <- function(etype, node1, node2) {
    # Increment edge counter.
    .global.inc("ddg.enum")
    ddg.enum <- .global.get("ddg.enum")
    # If the table is full, make it bigger.
    ddg.edges <- .global.get("ddg.edges")
    if (nrow(ddg.edges) < ddg.enum) {
        size = 100
        new.rows <- data.frame(ddg.num = numeric(size), ddg.type = character(size),
            ddg.from = character(size), ddg.to = character(size), stringsAsFactors = FALSE)
        .ddg.add.rows("ddg.edges", new.rows)
        ddg.edges <- .global.get("ddg.edges")
    }
    ddg.edges$ddg.num[ddg.enum] <- ddg.enum
    ddg.edges$ddg.type[ddg.enum] <- etype
    ddg.edges$ddg.from[ddg.enum] <- node1
    ddg.edges$ddg.to[ddg.enum] <- node2
    .global.set("ddg.edges", ddg.edges)

    # Record in ddg.json
    if (etype == "cf")
      .json.control.edge(ddg.enum, node1, node2)
    else if (etype == "df.in")
      .json.data.in.edge(ddg.enum, node1, node2)
    else
      .json.data.out.edge(ddg.enum, node1, node2)

    if (.global.get("ddg.debug.lib")) {
        if (etype == "cf")
            etype.long <- "control flow" else if (etype == "df.in")
            etype.long <- "data flow in" else etype.long <- "data flow out"
        print(paste("Adding", etype.long, "edge", ddg.enum, "for", node1, "to", node2))
    }
}
