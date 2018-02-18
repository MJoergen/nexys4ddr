# The top level module should define the variables below then include
# this file.  The files listed should be in the same directory as the
# Makefile.  
#
#   variable	description
#   ----------  -------------
#   project	    project name (top level module should match this name)
#   top_module  top level module of the project
#   libdir	    path to library directory
#   libs	    library modules used
#   vfiles	    all local .v files
#   xilinx_cores  all local .xco files
#   vendor      vendor of FPGA (xilinx, altera, etc.)
#   family      FPGA device family (spartan3e) 
#   part        FPGA part name (xc4vfx12-10-sf363)
#   flashsize   size of flash for mcs file (16384)
#   optfile     (optional) xst extra opttions file to put in .scr
#   map_opts    (optional) options to give to map
#   par_opts    (optional) options to give to par
#   intstyle    (optional) intstyle option to all tools
#
#   files 		description
#   ----------  	------------
#   $(ucf_file)	ucf file
#
# Library modules should have a modules.mk in their root directory,
# namely $(libdir)/<libname>/module.mk, that simply adds to the vfiles
# and xilinx_cores variable.
#
# all the .xco files listed in xilinx_cores will be generated with core, with
# the resulting .v and .ngc files placed back in the same directory as
# the .xco file.
#
# TODO: .xco files are device dependant, should use a template based system


#############################################
# Global variables
#############################################

coregen_work_dir ?= ./coregen-tmp
map_opts     ?= -timing -ol high -detail -pr b -register_duplication -w
par_opts     ?= -ol high
isedir       ?= /opt/Xilinx/14.7/ISE_DS
xil_env      ?= . $(isedir)/settings64.sh
flashsize    ?= 8192
app_bin      ?= ~/bin/$(project)
digilent_dir ?= /opt/Digilent/digilent.adept.runtime_2.10.2-i686
top_module   ?= $(project)

# Simulation
testbench    ?= $(top_module)_tb
tb_sources   ?= $(testbench).vhd
wave         ?= $(top_module).ghw
wavesave     ?= $(top_module).gtkw
unisim_lib   ?= unisim-obj93.cf
simprim_lib  ?= simprim-obj93.cf
stoptime     ?= --stop-time=10us

# Synthesis
vendor       ?= xilinx
family       ?= spartan3e
part         ?= xc3s250e-5-cp132
vfiles       ?= $(sources)
board        ?= Basys2
index        ?= 0

# Host PC application
app_source   ?= $(project).cpp
app_bin      ?= ~/bin/$(project)
app_libs     ?= -ldmgr -ldepp

UNISIMS_DIR          = $(isedir)/ISE/vhdl/src/unisims
SIMPRIM_DIR          = $(isedir)/ISE/vhdl/src/simprims
DIGILENT_INCLUDE_DIR = $(digilent_dir)/include 
DIGILENT_LIB_DIR     = $(digilent_dir)/lib

libmks = $(patsubst %,$(libdir)/%/module.mk,$(libs)) 
mkfiles = Makefile $(libmks) xilinx_ise.mk
include $(libmks)

corengcs = $(foreach core,$(xilinx_cores),$(core:.xco=.ngc))
local_corengcs = $(foreach ngc,$(corengcs),$(notdir $(ngc)))
vfiles += $(foreach core,$(xilinx_cores),$(core:.xco=.v))
junk += $(local_corengcs)

#############################################
# Simulation targets
# show: Display the results of the latest simulation
# sim:  Delete latest results and rerun simulation
#############################################

.PHONY: show sim net_sim net_uni
show: $(wave)
	export LD_LIBRARY_PATH=/usr/lib64
	gtkwave $(wave) $(wavesave)

sim:
	rm -f $(wave)
	make show

net_sim: $(wave)_sim

net_uni: $(wave)_uni

$(testbench)_sim: $(simprim_lib) $(vfiles) $(tb_sources) $(project)_sim.vhd
	ghdl -i --work=work $(project)_sim.vhd $(tb_sources)
	ghdl -m --ieee=synopsys -fexplicit $(testbench)
	mv $(testbench) $(testbench)_sim

$(testbench)_uni: $(unisim_lib) $(vfiles) $(tb_sources) $(project)_uni.vhd
	ghdl -i --work=work $(project)_uni.vhd $(tb_sources)
	ghdl -m --ieee=synopsys -fexplicit $(testbench)
	mv $(testbench) $(testbench)_uni

$(wave)_sim: $(testbench)_sim
	-ghdl -r $(testbench)_sim --assert-level=error --wave=$(wave) $(stoptime)

$(wave)_uni: $(testbench)_uni
	-ghdl -r $(testbench)_uni --assert-level=error --wave=$(wave) $(stoptime)

$(wave): $(testbench)
	-ghdl -r $(testbench) --assert-level=error --wave=$(wave) $(stoptime)

$(testbench): $(testbench).o $(unisim_lib) $(vfiles) $(tb_sources)
	ghdl -m --ieee=synopsys -fexplicit $(testbench)

$(unisim_lib):
	ghdl -i --work=unisim $(UNISIMS_DIR)/*vhd
	ghdl -i --work=unisim $(UNISIMS_DIR)/primitive/*vhd
	
$(simprim_lib):
	ghdl -i --work=simprim $(SIMPRIM_DIR)/simprim_Vpackage.vhd
	ghdl -i --work=simprim $(SIMPRIM_DIR)/simprim_Vcomponents.vhd
	ghdl -i --work=simprim $(SIMPRIM_DIR)/primitive/other/*vhd
	
$(testbench).o: $(vfiles) $(tb_sources)
	ghdl -i --work=work $(vfiles) $(tb_sources)

clean::
	rm -f *.o work-obj93.cf $(testbench) $(wave) $(top_module)

#############################################
# Host PC application targets
# app:  Compile the host PC application.
#############################################

.PHONY: app
app: $(app_bin)

$(app_bin): $(app_source)
	g++ -g -Wall $(app_source) -I $(DIGILENT_INCLUDE_DIR) -L $(DIGILENT_LIB_DIR) $(app_libs) -o $(app_bin)


#############################################
# Synthesis targets
#############################################

$(project)_uni.vhd: $(project).ngc
	$(xil_env); \
	netgen -sim -w -ofmt vhdl $(project).ngc
	mv $(project).vhd $(project)_uni.vhd

$(project)_sim.vhd: $(project).ngd
	$(xil_env); \
	netgen -sim -w -ofmt vhdl $(project).ngd
	mv $(project).vhd $(project)_sim.vhd

.PHONY: program
program: $(project).bit
	djtgcfg prog -d $(board) -i $(index) -f $(project).bit

.PHONY: synth prom xilinx_cores clean twr etwr
synth: $(project).bit
prom: $(project).mcs
xilinx_cores: $(corengcs)
twr: $(project).twr
etwr: $(project)_err.twr

define cp_template
$(2): $(1)
	cp $(1) $(2)
endef
$(foreach ngc,$(corengcs),$(eval $(call cp_template,$(ngc),$(notdir $(ngc)))))

%.ngc %.v: %.xco
	@echo "=== rebuilding $@"
	if [ -d $(coregen_work_dir) ]; then \
		rm -rf $(coregen_work_dir)/*; \
	else \
		mkdir -p $(coregen_work_dir); \
	fi
	cd $(coregen_work_dir); \
	$(xil_env); \
	coregen -b $$OLDPWD/$<; \
	cd -
	xcodir=`dirname $<`; \
	basename=`basename $< .xco`; \
	if [ ! -r $(coregen_work_dir/$$basename.ngc) ]; then \
		echo "'$@' wasn't created."; \
		exit 1; \
	else \
		cp $(coregen_work_dir)/$$basename.v $(coregen_work_dir)/$$basename.ngc $$xcodir; \
	fi
junk += $(coregen_work_dir)

date = $(shell date +%F-%H-%M)

# some common junk
junk += *.xrpt
junk += usage_statistics_webtalk.html webtalk.log
junk += _xmsgs

programming_files: $(project).bit $(project).mcs
	mkdir -p $@/$(date)
	mkdir -p $@/latest
	for x in .bit .mcs .cfi _bd.bmm; do cp $(project)$$x $@/$(date)/$(project)$$x; cp $(project)$$x $@/latest/$(project)$$x; done
	$(xil_env); xst -help | head -1 | sed 's/^/#/' | cat - $(project).scr > $@/$(date)/$(project).scr

$(project).mcs: $(project).bit
	$(xil_env); \
	promgen -w -s $(flashsize) -p mcs -o $@ -u 0 $^
junk += $(project).mcs $(project).cfi $(project).prm

$(project).bit: $(project)_par.ncd
	#$(xil_env); \
	#bitgen $(intstyle) -g DriveDone:yes -g StartupClk:Cclk -w $(project)_par.ncd $(project).bit
	$(xil_env); \
	bitgen $(intstyle) -g DriveDone:yes -g StartupClk:JtagClk -w $(project)_par.ncd $(project).bit
junk += $(project).bgn $(project).bit $(project).drc $(project)_bd.bmm $(project)_bitgen.xwbt


$(project)_par.ncd: $(project).ncd
	$(xil_env); \
	if par $(intstyle) $(par_opts) -w $(project).ncd $(project)_par.ncd; then \
		:; \
	else \
		$(MAKE) etwr; \
	fi 
junk += $(project)_par.ncd $(project)_par.par $(project)_par.pad 
junk += $(project)_par_pad.csv $(project)_par_pad.txt 
junk += $(project)_par.grf $(project)_par.ptwx
junk += $(project)_par.unroutes $(project)_par.xpi

$(project).ncd: $(project).ngd
	if [ -r $(project)_par.ncd ]; then \
		cp $(project)_par.ncd smartguide.ncd; \
		smartguide="-smartguide smartguide.ncd"; \
	else \
		smartguide=""; \
	fi; \
	$(xil_env); \
	map $(intstyle) $(map_opts) $$smartguide $<
junk += $(project).ncd $(project).pcf $(project).ngm $(project).mrp $(project).map
junk += smartguide.ncd $(project).psr 
junk += $(project)_summary.xml $(project)_usage.xml

#$(project).ngd: $(project).ngc $(ucf_file) $(project).bmm
$(project).ngd: $(project).ngc $(ucf_file)
	$(xil_env); ngdbuild $(intstyle) $(project).ngc #-bm $(project).bmm
junk += $(project).ngd $(project).bld

$(project).ngc: $(vfiles) $(local_corengcs) $(project).scr $(project).prj
	$(xil_env); xst $(intstyle) -ifn $(project).scr
junk += xlnx_auto* $(top_module).lso $(project).srp 
junk += netlist.lst xst $(project).ngc

$(project).prj: $(vfiles) $(mkfiles)
	for src in $(vfiles); do echo "vhdl work $$src" >> $(project).tmpprj; done
	sort -u $(project).tmpprj > $(project).prj
	rm -f $(project).tmpprj
junk += $(project).prj

optfile += $(wildcard $(project).opt)
$(project).scr: $(optfile) $(mkfiles) xilinx.opt
	echo "run" > $@
	echo "-p $(part)" >> $@
	echo "-top $(top_module)" >> $@
	echo "-ifn $(project).prj" >> $@
	echo "-ofn $(project).ngc" >> $@
	cat xilinx.opt $(optfile) >> $@
junk += $(project).scr

$(project).post_map.twr: $(project).ncd
	$(xil_env); trce -e 10 $< $(project).pcf -o $@
junk += $(project).post_map.twr $(project).post_map.twx smartpreview.twr

$(project).twr: $(project)_par.ncd
	$(xil_env); trce $< $(project).pcf -o $(project).twr
junk += $(project).twr $(project).twx smartpreview.twr

$(project)_err.twr: $(project)_par.ncd
	$(xil_env); trce -e 10 $< $(project).pcf -o $(project)_err.twr
junk += $(project)_err.twr $(project)_err.twx

.gitignore: $(mkfiles)
	echo programming_files $(junk) | sed 's, ,\n,g' > .gitignore

clean::
	rm -rf $(junk)

