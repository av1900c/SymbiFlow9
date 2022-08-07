#!/usr/bin/env python3
"""
Convert a Verilog simulation model to a VPR `model.xml`

The following Verilog attributes are considered on ports:
    - `(* CLOCK *)` : force a given port to be a clock

    - `(* ASSOC_CLOCK="RDCLK" *)` : force a port's associated
                                    clock to a given value

The following Verilog attributes are considered on modules:
    - `(* MODEL_NAME="model" *)` : override the name used for
    <model> and for ".subckt name" in the BLIF model. Mostly
    intended for use with w.py, when several different pb_types
    implement the same model.

    - `(* CLASS="lut|routing|mux|flipflop|mem" *)` : specify the
    class of an given instance. A model will not be generated for
    the `lut`, `routing` or `flipflop` class.
"""
import os
import re
import sys

import lxml.etree as ET

from .yosys import run
from .yosys.json import YosysJSON

from .xmlinc import xmlinc


def is_clock_assoc(infiles, module, clk, port, direction):
    """Checks if a specific port is associated with a clk clock

    Returns a boolean value
    -------
    is_clock_assoc: bool
    """
    clock_assoc_signals = run.get_clock_assoc_signals(
        infiles, module, clk
    )

    if direction == "input":
        assoc_outputs = run.get_related_output_for_input(
            infiles, module, port
        )
        for out in assoc_outputs:
            if out in clock_assoc_signals:
                return True
    elif direction == "output":
        if port in clock_assoc_signals:
            return True
    else:
        assert False, "Bidirectional ports are not supported yet"

    return False


def is_registered_path(tmod, pin, pout):
    """Checks if a i/o path is sequential. If that is the case
    no combinational_sink_port is needed

    Returns a boolean value
    """

    for cell, ctype in tmod.all_cells:
        if ctype != "$dff":
            continue

        if tmod.port_conns(pin) == tmod.cell_conn_list(
                cell, "D") and tmod.port_conns(pout) == tmod.cell_conn_list(
                    cell, "Q"):
            return True

    return False


def vlog_to_model(infiles, includes, top, outfile=None):
    iname = os.path.basename(infiles[0])

    if outfile is None:
        outfile = "model.xml"

    if includes:
        for include in includes.split(','):
            run.add_include(include)

    aig_json = run.vlog_to_json(infiles, flatten=True, aig=True)

    if top is not None:
        top = top.upper()
    else:
        yj = YosysJSON(aig_json)
        if yj.top is not None:
            top = yj.top
        else:
            wm = re.match(r"([A-Za-z0-9_]+)\.sim\.v", iname)
            if wm:
                top = wm.group(1).upper()
            else:
                print(
                    """\
    ERROR file name not of format %.sim.v ({}), cannot detect top level.
    Manually specify the top level module using --top"""
                ).format(iname)
                sys.exit(1)

    assert top is not None
    yj = YosysJSON(aig_json, top)
    if top is None:
        print(
            """\
    ERROR: more than one module in design, cannot detect top level.
    Manually specify the top level module using --top"""
        )
        sys.exit(1)

    tmod = yj.top_module
    models_xml = ET.Element("models", nsmap={'xi': xmlinc.xi_url})

    inc_re = re.compile(r'^\s*`include\s+"([^"]+)"')

    deps_files = set()
    # XML dependencies need to correspond 1:1 with Verilog includes, so we have
    # to do this manually rather than using Yosys
    with open(infiles[0], 'r') as f:
        for line in f:
            im = inc_re.match(line)
            if not im:
                continue
            deps_files.add(im.group(1))

    if len(deps_files) > 0:
        # Has dependencies, not a leaf model
        for df in sorted(deps_files):
            abs_base = os.path.dirname(os.path.abspath(infiles[0]))
            abs_dep = os.path.normpath(os.path.join(abs_base, df))
            module_path = os.path.dirname(abs_dep)
            module_basename = os.path.basename(abs_dep)
            wm = re.match(r"([A-Za-z0-9_]+)\.sim\.v", module_basename)
            if wm:
                model_path = "{}/{}.model.xml".format(
                    module_path,
                    wm.group(1).lower()
                )
            else:
                assert False, "included Verilog file name {} does \
                        not follow pattern %%.sim.v".format(
                    module_basename
                )
            xmlinc.include_xml(
                parent=models_xml,
                href=model_path,
                outfile=outfile,
                xptr="xpointer(models/child::node())"
            )
    else:
        # Is a leaf model
        topname = tmod.attr("MODEL_NAME", top)
        assert topname == topname.upper(
        ), "Leaf model names should be all uppercase!"
        modclass = tmod.attr("CLASS", "")

        if modclass not in ("lut", "routing", "flipflop"):
            model_xml = ET.SubElement(models_xml, "model", {'name': topname})
            ports = tmod.ports

            inports_xml = ET.SubElement(model_xml, "input_ports")
            outports_xml = ET.SubElement(model_xml, "output_ports")

            clocks = run.list_clocks(infiles, top)

            for name, width, bits, iodir in ports:
                attrs = dict(name=name)
                sinks = run.get_combinational_sinks(infiles, top, name)

                # Removes comb sinks if path from in to out goes through a dff
                for sink in sinks:
                    if is_registered_path(tmod, name, sink):
                        sinks.remove(sink)

                # FIXME: Check if ignoring clock for "combination_sink_ports"
                # is a valid thing to do.
                if name in clocks or "clk" in name.lower():
                    attrs["is_clock"] = "1"
                else:
                    clks = list()
                    if len(sinks) > 0 and iodir == "input":
                        attrs["combinational_sink_ports"] = " ".join(sinks)
                    for clk in clocks:
                        if is_clock_assoc(infiles, top, clk, name, iodir):
                            clks.append(clk)
                        if clks:
                            attrs["clock"] = " ".join(clks)
                if iodir == "input":
                    ET.SubElement(inports_xml, "port", attrs)
                elif iodir == "output":
                    ET.SubElement(outports_xml, "port", attrs)
                else:
                    assert False, "bidirectional ports not permitted \
                                  in VPR models"

    if len(models_xml) == 0:
        models_xml.insert(0,
                          ET.Comment("this file is intentionally left blank"))

    return ET.tostring(models_xml, pretty_print=True).decode('utf-8')
