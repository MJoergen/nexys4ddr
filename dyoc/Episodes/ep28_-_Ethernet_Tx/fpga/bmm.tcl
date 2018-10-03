set myInsts [get_cells -hier -filter {PRIMITIVE_TYPE =~ BMEM.*.* && NAME =~ *i_rom*}]
set bmmList {}; # make it empty incase you were running it interactively
foreach memInst $myInsts {
   set loc [get_property LOC $memInst]
   # for BMM the location is just the XY location so remove the extra data
   set loc [string trimleft $loc RAMB36_]
   # find the bus index, this is specific to our design
   set idx [string last "_" $memInst]
   set busIndex [string range $memInst $idx+1 999]
   set first [expr {2*(3-$busIndex)}]
   set last [expr {2*(3-$busIndex)+1}]
   # build a list in a format which is close to the output we need
   set x "$memInst \[$last:$first\] LOC = $loc"
   lappend bmmList $x
}

set fp [open comp.bmm w]

# The format of the BMM file is specificed in the data2mem manual and
# this is what just works for us so if you want something different
# then you need to understand how this file behaves.
puts $fp "ADDRESS_SPACE rom RAMB32 \[0xC000:0xFFFF\]"
puts $fp "   BUS_BLOCK"
foreach printList [lsort -decreasing -dictionary $bmmList] {
   puts $fp "      $printList;"
}
puts $fp "   END_BUS_BLOCK;"
puts $fp "END_ADDRESS_SPACE;"

close $fp

unset myInsts
unset bmmList
unset loc
unset idx
unset busIndex
unset first
unset last
unset x
unset fp

