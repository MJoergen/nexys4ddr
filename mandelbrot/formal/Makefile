# Simple Makefile which just runs through all the DUTs.

DUTS  = res_scheduler
DUTS += job_scheduler
DUTS += job
DUTS += dispatcher_jobs

# One stamp file per DUT, touched only when sby exits successfully.
STAMPS = $(addsuffix .stamp,$(DUTS))

all: $(STAMPS)

# Every file a job reads, taken from that job's own [files] section, so the
# prerequisites cannot drift out of step with the job description.
sby_files = $(shell sed -n '/^\[files\]/,$$p' $(1).sby | tail -n +2)

$(foreach d,$(DUTS),$(eval $(d).stamp: $(d).sby $(call sby_files,$(d))))

# The stamp is removed before sby runs and recreated only on success, so
# "stamp exists" always means "the last run of this job passed".
%.stamp:
	rm -f $@
	sby --yosys "yosys -m ghdl" -f $*.sby
	@touch $@

clean:
	rm -rf $(STAMPS)
	rm -rf $(foreach d,$(DUTS),$(d) $(d)_bmc* $(d)_cover* $(d)_prove*)

.PHONY: all clean
