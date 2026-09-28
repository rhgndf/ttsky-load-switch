set top tt_um_rhgndf_load_switch
set template /home/ubuntu/ref/tt-support-tools/tech/sky130A/def/analog/tt_analog_1x2_3v3.def
set root [file normalize [file dirname [file dirname [info script]]]]
set gds_path [file join $root gds "$top.gds"]
set lef_path [file join $root lef "$top.lef"]
set cell_gds_dir [file join [file normalize ~] layout_logs subckts]
set layout_stage logic
if {[info exists ::env(LAYOUT_STAGE)]} {
    set layout_stage $::env(LAYOUT_STAGE)
}
set layout_target top
if {[info exists ::env(LAYOUT_TARGET)]} {
    set layout_target $::env(LAYOUT_TARGET)
}
if {$layout_stage ni {logic analog resistors mim routing}} {
    error "Unknown LAYOUT_STAGE: $layout_stage"
}
if {$layout_target ni {top subckts}} {
    error "Unknown LAYOUT_TARGET: $layout_target"
}

proc paint_rect {layer x1 y1 x2 y2} {
    box ${x1}um ${y1}um ${x2}um ${y2}um
    paint $layer
}

proc paint_m2_path {points} {
    set width 0.4
    for {set i 0} {$i < [expr {[llength $points] - 1}]} {incr i} {
        lassign [lindex $points $i] x1 y1
        lassign [lindex $points [expr {$i + 1}]] x2 y2
        if {abs($x1 - $x2) < 1.0e-6} {
            paint_rect met2 [expr {$x1 - $width / 2.0}] [expr {min($y1, $y2) - $width / 2.0}] \
                [expr {$x1 + $width / 2.0}] [expr {max($y1, $y2) + $width / 2.0}]
        } elseif {abs($y1 - $y2) < 1.0e-6} {
            paint_rect met2 [expr {min($x1, $x2) - $width / 2.0}] [expr {$y1 - $width / 2.0}] \
                [expr {max($x1, $x2) + $width / 2.0}] [expr {$y1 + $width / 2.0}]
        } else {
            error "Resistor route is not Manhattan"
        }
    }
}

proc paint_m3_path {points} {
    set width 0.4
    for {set i 0} {$i < [expr {[llength $points] - 1}]} {incr i} {
        lassign [lindex $points $i] x1 y1
        lassign [lindex $points [expr {$i + 1}]] x2 y2
        if {abs($x1 - $x2) < 1.0e-6} {
            paint_rect met3 [expr {$x1 - $width / 2.0}] [expr {min($y1, $y2) - $width / 2.0}] \
                [expr {$x1 + $width / 2.0}] [expr {max($y1, $y2) + $width / 2.0}]
        } elseif {abs($y1 - $y2) < 1.0e-6} {
            paint_rect met3 [expr {min($x1, $x2) - $width / 2.0}] [expr {$y1 - $width / 2.0}] \
                [expr {max($x1, $x2) + $width / 2.0}] [expr {$y1 + $width / 2.0}]
        } else {
            error "Resistor route is not Manhattan"
        }
    }
}

proc paint_m4_path {points} {
    set width 0.4
    for {set i 0} {$i < [expr {[llength $points] - 1}]} {incr i} {
        lassign [lindex $points $i] x1 y1
        lassign [lindex $points [expr {$i + 1}]] x2 y2
        if {abs($x1 - $x2) < 1.0e-6} {
            paint_rect met4 [expr {$x1 - $width / 2.0}] [expr {min($y1, $y2) - $width / 2.0}] \
                [expr {$x1 + $width / 2.0}] [expr {max($y1, $y2) + $width / 2.0}]
        } elseif {abs($y1 - $y2) < 1.0e-6} {
            paint_rect met4 [expr {min($x1, $x2) - $width / 2.0}] [expr {$y1 - $width / 2.0}] \
                [expr {max($x1, $x2) + $width / 2.0}] [expr {$y1 + $width / 2.0}]
        } else {
            error "MIM route is not Manhattan"
        }
    }
}

proc make_res_port_label {name x y use layer} {
    box ${x}um ${y}um ${x}um ${y}um
    label $name FreeSans 0.25u -$layer
    port make
    port use $use
    port class bidirectional
    port connections n s e w
}

proc route_res_contact {x y} {
    paint_rect locali [expr {$x - 0.22}] [expr {$y - 0.22}] [expr {$x + 0.22}] [expr {$y + 0.22}]
    paint_rect mcon [expr {$x - 0.16}] [expr {$y - 0.16}] [expr {$x + 0.16}] [expr {$y + 0.16}]
    paint_rect met1 [expr {$x - 0.22}] [expr {$y - 0.22}] [expr {$x + 0.22}] [expr {$y + 0.22}]
    paint_rect via1 [expr {$x - 0.16}] [expr {$y - 0.16}] [expr {$x + 0.16}] [expr {$y + 0.16}]
    paint_rect met2 [expr {$x - 0.22}] [expr {$y - 0.22}] [expr {$x + 0.22}] [expr {$y + 0.22}]
}

proc route_res_body_contact {x y exit_x} {
    paint_rect locali [expr {$x - 0.22}] [expr {$y - 0.22}] [expr {$x + 0.22}] [expr {$y + 0.22}]
    paint_rect mcon [expr {$x - 0.16}] [expr {$y - 0.16}] [expr {$x + 0.16}] [expr {$y + 0.16}]
    paint_rect met1 [expr {$x - 0.22}] [expr {$y - 0.22}] [expr {$x + 0.22}] [expr {$y + 0.22}]
    paint_rect met1 [expr {min($x, $exit_x) - 0.2}] [expr {$y - 0.2}] [expr {max($x, $exit_x) + 0.2}] [expr {$y + 0.2}]
    paint_rect via1 [expr {$exit_x - 0.16}] [expr {$y - 0.16}] [expr {$exit_x + 0.16}] [expr {$y + 0.16}]
    paint_rect met2 [expr {$exit_x - 0.22}] [expr {$y - 0.22}] [expr {$exit_x + 0.22}] [expr {$y + 0.22}]
    paint_rect via2 [expr {$exit_x - 0.16}] [expr {$y - 0.16}] [expr {$exit_x + 0.16}] [expr {$y + 0.16}]
    paint_rect met3 [expr {$exit_x - 0.22}] [expr {$y - 0.22}] [expr {$exit_x + 0.22}] [expr {$y + 0.22}]
}

proc make_mos {parent name type w l} {
    set cellpath "$name.mag"
    file delete -force $cellpath
    load $name
    box 0 0 0 0
    set params [dict create w $w l $l nf 1 m 1 doports 1 guard 1 poverlap 0 topc 1 botc 1 drain D source S gate G bulk B]
    if {$type eq "n"} {
        sky130::sky130_fd_pr__nfet_g5v0d10v5_draw $params
    } else {
        sky130::sky130_fd_pr__pfet_g5v0d10v5_draw $params
    }
    save $cellpath
    load $parent
}

proc make_res_group {} {
    global top
    set cell res_group
    file delete -force "$cell.mag"
    load $cell
    box 0 0 0 0
    set newdict [dict create res_type xpres end_type xpc end_contact_type xpc \
        plus_diff_type psd plus_contact_type psc sub_type psub guard_sub_surround 0 \
        end_surround [dict get $sky130::ruleset poly_surround] end_spacing 0.48 \
        end_to_end_space 0.52 end_contact_size 0.19 res_to_cont 0.575 \
        res_to_endcont 1.985 res_spacing 0.48 res_diff_spacing 0.48 \
        mask_clearance 0.52 overlap_compress 0.36 l_delta -0.08]
    set base_params [dict merge $sky130::ruleset $newdict]
    set measure_params [dict merge $base_params [dict create w 0.69 l 40]]
    tech lock *
    box 0 0 0 0
    set bbox [sky130::res_device $measure_params]
    tech unlock *
    set fw [expr {[lindex $bbox 2] - [lindex $bbox 0]}]
    set fh [expr {[lindex $bbox 3] - [lindex $bbox 1]}]
    set dx [expr {$fw + 0.48}]
    set corex [expr {4 * $dx + $fw}]
    set gx [expr {$corex + 2 * (0.48 + 0.0) + [dict get $base_params contact_size]}]
    set gy [expr {$fh + 2 * (0.48 + 0.0) + [dict get $base_params contact_size]}]
    set guard_params [dict merge $base_params [dict create bulk B]]
    sky130::guard_ring $gx $gy $guard_params
    for {set i 0} {$i < 5} {incr i} {
        set length 40
        if {$i == 4} {set length 2}
        set params [dict merge $base_params [dict create \
            w 0.69 l $length doports 1 term_t R1_$i term_b R2_$i]]
        set center_x [expr {($i - 2) * $dx}]
        box ${center_x}um 0um ${center_x}um 0um
        sky130::res_device $params
    }
    save "$cell.mag"
    load $cell
    set bbox [cell_bbox "$cell.mag"]
    lassign $bbox x1 y1 x2 y2
    array set r1x {}
    array set r1y {}
    array set r2x {}
    array set r2y {}
    for {set i 0} {$i < 5} {incr i} {
        lassign [label_center "$cell.mag" "R1_$i" resistor] r1x($i) r1y($i) layer
        lassign [label_center "$cell.mag" "R2_$i" resistor] r2x($i) r2y($i) layer
        route_res_contact $r1x($i) $r1y($i)
        route_res_contact $r2x($i) $r2y($i)
    }
    lassign [label_center "$cell.mag" B resistor] bx by layer
    set body_route_x [expr {$x1 - 2.0}]
    route_res_body_contact $bx $by $body_route_x
    for {set i 0} {$i < 3} {incr i} {
        set xmid [expr {($r2x($i) + $r1x([expr {$i + 1}])) / 2.0}]
        paint_m2_path [list \
            [list $r2x($i) $r2y($i)] \
            [list $xmid $r2y($i)] \
            [list $xmid $r1y([expr {$i + 1}])] \
            [list $r1x([expr {$i + 1}]) $r1y([expr {$i + 1}])]]
    }
    set top_port_y [expr {$y2 + 7.0}]
    set nb_port_y [expr {$y1 - 7.0}]
    set gate_port_y [expr {$y1 - 8.5}]
    set body_port_y [expr {$y1 - 10.0}]
    paint_m2_path [list [list $r1x(0) $r1y(0)] [list $r1x(0) $top_port_y]]
    paint_m2_path [list [list $r2x(3) $r2y(3)] [list $r2x(3) $nb_port_y]]
    paint_m2_path [list [list $r1x(4) $r1y(4)] [list $r1x(4) [expr {$top_port_y + 2.0}]]]
    paint_rect via2 [expr {$r2x(4) - 0.16}] [expr {$r2y(4) - 0.16}] [expr {$r2x(4) + 0.16}] [expr {$r2y(4) + 0.16}]
    paint_rect met3 [expr {$r2x(4) - 0.22}] [expr {$r2y(4) - 0.22}] [expr {$r2x(4) + 0.22}] [expr {$r2y(4) + 0.22}]
    paint_m3_path [list [list $r2x(4) $r2y(4)] [list $r2x(4) $gate_port_y]]
    paint_m3_path [list \
        [list $bx $by] \
        [list $body_route_x $by] \
        [list $body_route_x $body_port_y]]
    make_res_port_label VAPWR $r1x(0) $top_port_y power met2
    make_res_port_label nb $r2x(3) $nb_port_y signal met2
    make_res_port_label cz $r1x(4) [expr {$top_port_y + 2.0}] signal met2
    make_res_port_label GATE $r2x(4) $gate_port_y signal met3
    make_res_port_label VGND $body_route_x $body_port_y ground met3
    save "$cell.mag"
    load $top
}

proc cell_bbox {path} {
    set fh [open $path r]
    set layer ""
    set min_x 1.0e9
    set min_y 1.0e9
    set max_x -1.0e9
    set max_y -1.0e9
    while {[gets $fh line] >= 0} {
        if {[regexp {^<< ([^ >]+) >>$} $line -> layer]} {
            continue
        }
        if {$layer eq "checkpaint"} {
            continue
        }
        if {[regexp {^rect (-?[0-9.]+) (-?[0-9.]+) (-?[0-9.]+) (-?[0-9.]+)$} $line -> x1 y1 x2 y2]} {
            if {$x1 < $min_x} {set min_x $x1}
            if {$y1 < $min_y} {set min_y $y1}
            if {$x2 > $max_x} {set max_x $x2}
            if {$y2 > $max_y} {set max_y $y2}
        }
    }
    close $fh
    if {$max_x < $min_x || $max_y < $min_y} {
        error "No drawable geometry in $path"
    }
    return [list [expr {$min_x / 200.0}] [expr {$min_y / 200.0}] [expr {$max_x / 200.0}] [expr {$max_y / 200.0}]]
}

proc label_center {path pin kind} {
    set fh [open $path r]
    set candidates {}
    while {[gets $fh line] >= 0} {
        set fields [regexp -all -inline {[^[:space:]]+} $line]
        if {[llength $fields] == 9 && [lindex $fields 0] eq "rlabel"} {
            lassign $fields keyword layer orientation x1 y1 x2 y2 port name
        } elseif {[llength $fields] == 8 && [lindex $fields 0] eq "rlabel"} {
            lassign $fields keyword layer x1 y1 x2 y2 port name
        } elseif {[lindex $fields 0] eq "flabel" && [llength $fields] == 13} {
            lassign $fields keyword layer x1 y1 x2 y2 port font size justify rotate ignored name
        } elseif {[lindex $fields 0] eq "flabel" && [llength $fields] == 14} {
            lassign $fields keyword layer orientation x1 y1 x2 y2 port font size justify rotate ignored name
        } else {
            continue
        }
        if {[string match "metal*" $layer]} {
            set layer [string map {metal met} $layer]
        }
        if {$name ne $pin || $layer eq "comment"} {
            continue
        }
        set priority 10
        if {$kind eq "mos"} {
            if {$pin eq "B" && $layer in {mvnsubdiffcont mvpsubdiffcont}} {set priority 0}
            if {$pin eq "G" && $layer eq "polycont"} {set priority 0}
            if {$pin in {D S} && $layer in {mvndiffc mvpdiffc}} {set priority 0}
        } elseif {$kind eq "capacitor"} {
            if {$pin eq "C1" && $layer eq "mimcapcontact"} {set priority 0}
            if {$pin eq "C2" && $layer eq "via3"} {set priority 0}
        }
        lappend candidates [list $priority $x1 $y1 $x2 $y2 $layer]
    }
    close $fh
    if {[llength $candidates] == 0} {
        error "No $pin port in $path"
    }
    set candidates [lsort -integer -index 0 $candidates]
    lassign [lindex $candidates 0] priority x1 y1 x2 y2 layer
    return [list [expr {($x1 + $x2) / 400.0}] [expr {($y1 + $y2) / 400.0}] $layer]
}

array set endpoints {}
array set logic_cell_width {}
array set logic_cell_height {}
array set logic_instance_xy {}
set res_group_global_bbox {}
set mimcap_global_bbox {}
proc add_net_pin {path x y pin net kind} {
    global endpoints
    lassign [label_center $path $pin $kind] px py layer
    if {![info exists endpoints($net)]} {
        set endpoints($net) {}
    }
    lappend endpoints($net) [list [expr {$x + $px}] [expr {$y + $py}] $kind $pin $layer]
}

proc place_existing_mos {name x y pinmap} {
    box 0 0 0 0
    getcell $name child 0 0 parent [expr {round($x * 200)}] [expr {round($y * 200)}]
    foreach {pin net} $pinmap {
        add_net_pin "$name.mag" $x $y $pin $net mos
    }
}

proc x_access {x pin kind} {
    if {$kind eq "mos"} {
        switch -- $pin {
            D {return $x}
            S {return $x}
            G {return [expr {$x + 1.0}]}
            B {return [expr {$x - 1.0}]}
        }
    }
    return [expr {$x + 0.35}]
}

proc paint_via1 {x y} {
    box [expr {$x - 0.13}]um [expr {$y - 0.13}]um [expr {$x + 0.13}]um [expr {$y + 0.13}]um
    sky130::via1_draw
}

proc route_mos_endpoint {x y pin layer lane {track_x ""}} {
    set local_route [expr {$track_x eq ""}]
    set ax [x_access $x $pin mos]
    set ay $y
    if {$local_route} {
        set track_x $ax
    }
    if {$pin eq "G"} {
        set ay [expr {$y + 1.0}]
    }
    if {$pin eq "B"} {
        paint_rect locali [expr {$x - 0.18}] [expr {$y - 0.18}] [expr {$x + 0.18}] [expr {$y + 0.18}]
        box [expr {$x - 0.10}]um [expr {$y - 0.10}]um [expr {$x + 0.10}]um [expr {$y + 0.10}]um
        sky130::mcon_draw vert
    }
    if {$pin eq "G"} {
        paint_rect met1 [expr {$x - 0.08}] [expr {min($y,$ay) - 0.08}] [expr {$x + 0.08}] [expr {max($y,$ay) + 0.08}]
        paint_rect met1 [expr {min($x,$ax) - 0.08}] [expr {$ay - 0.08}] [expr {max($x,$ax) + 0.08}] [expr {$ay + 0.08}]
        paint_rect met1 [expr {$ax - 0.22}] [expr {$ay - 0.22}] [expr {$ax + 0.22}] [expr {$ay + 0.22}]
    } else {
        paint_rect met1 [expr {$x - 0.22}] [expr {$y - 0.22}] [expr {$x + 0.22}] [expr {$y + 0.22}]
        paint_rect met1 [expr {min($x,$ax) - 0.22}] [expr {$y - 0.22}] [expr {max($x,$ax) + 0.22}] [expr {$y + 0.22}]
    }
    paint_via1 $ax $ay
    if {$local_route} {
        if {abs($ay - $lane) > 1.0e-6} {
            paint_m2_path [list [list $ax $ay] [list $ax $lane]]
        }
        paint_via2 $ax $lane
        return $ax
    }
    paint_via2 $ax $ay
    if {abs($ax - $track_x) > 1.0e-6} {
        paint_m3_path [list [list $ax $ay] [list $track_x $ay]]
    }
    if {abs($ax - $track_x) < 1.0e-6} {
        paint_via2 $track_x $ay 1
    } else {
        paint_via2 $track_x $ay
    }
    if {abs($ay - $lane) > 1.0e-6} {
        paint_m2_path [list [list $track_x $ay] [list $track_x $lane]]
    }
    paint_via2 $track_x $lane 1
    return $track_x
}

proc paint_via2 {x y {wide_m3 0}} {
    box [expr {$x - 0.14}]um [expr {$y - 0.14}]um [expr {$x + 0.14}]um [expr {$y + 0.14}]um
    sky130::via2_draw
    if {$wide_m3} {
        paint_rect met3 [expr {$x - 0.31}] [expr {$y - 0.20}] [expr {$x + 0.31}] [expr {$y + 0.20}]
    }
}

proc paint_via3 {x y} {
    box [expr {$x - 0.16}]um [expr {$y - 0.16}]um [expr {$x + 0.16}]um [expr {$y + 0.16}]um
    sky130::via3_draw
    paint_rect met3 [expr {$x - 0.31}] [expr {$y - 0.20}] [expr {$x + 0.31}] [expr {$y + 0.20}]
}

proc route_metal_endpoint {x y layer lane track_x} {
    if {$layer eq "met4"} {
        paint_via3 $x $y
        if {abs($x - $track_x) > 1.0e-6} {
            paint_m3_path [list [list $x $y] [list $track_x $y]]
        }
        paint_via2 $track_x $y 1
    } elseif {$layer in {met3 via3 mimcapcontact}} {
        if {abs($x - $track_x) > 1.0e-6} {
            paint_m3_path [list [list $x $y] [list $track_x $y]]
        }
        if {abs($x - $track_x) < 1.0e-6} {
            paint_via2 $track_x $y 1
        } else {
            paint_via2 $track_x $y
        }
    } elseif {$layer ne "met2"} {
        error "Unsupported route endpoint layer $layer"
    } else {
        paint_via2 $x $y
        if {abs($x - $track_x) > 1.0e-6} {
            paint_m3_path [list [list $x $y] [list $track_x $y]]
        }
        paint_via2 $track_x $y
    }
    if {abs($y - $lane) > 1.0e-6} {
        paint_m2_path [list [list $track_x $y] [list $track_x $lane]]
    }
    paint_via2 $track_x $lane 1
    return $track_x
}

proc route_resistor_endpoint {x y pin layer lane track_x} {
    global res_group_global_bbox
    lassign $res_group_global_bbox x1 y1 x2 y2
    set ax $x
    if {$pin in {nb GATE}} {
        set ax [expr {$x2 + 1.0}]
    } elseif {$pin eq "VGND"} {
        set ax [expr {$x1 - 1.0}]
    }
    if {$ax != $x} {
        if {$layer eq "met3"} {
            paint_m3_path [list [list $x $y] [list $ax $y]]
        } elseif {$layer eq "met2"} {
            paint_m2_path [list [list $x $y] [list $ax $y]]
        } else {
            error "Unsupported resistor endpoint layer $layer"
        }
    } elseif {$layer ni {met2 met3}} {
        error "Unsupported resistor endpoint layer $layer"
    }
    if {abs($ax - $track_x) < 1.0e-6} {
        paint_via2 $ax $y 1
    } else {
        paint_via2 $ax $y
    }
    if {abs($ax - $track_x) > 1.0e-6} {
        paint_m3_path [list [list $ax $y] [list $track_x $y]]
    }
    if {abs($ax - $track_x) < 1.0e-6} {
        paint_via2 $track_x $y 1
    } else {
        paint_via2 $track_x $y
    }
    if {abs($y - $lane) > 1.0e-6} {
        paint_m2_path [list [list $track_x $y] [list $track_x $lane]]
    }
    paint_via2 $track_x $lane 1
    return $track_x
}

proc route_mim_endpoint {x y pin lane track_x} {
    if {$pin eq "C1"} {
        paint_m3_path [list [list $x $y] [list $track_x $y]]
    } elseif {$pin eq "C2"} {
        paint_m4_path [list [list $x $y] [list $track_x $y]]
        paint_via3 $track_x $y
    } else {
        error "Unsupported MIM terminal $pin"
    }
    paint_via2 $track_x $y 1
    if {abs($y - $lane) > 1.0e-6} {
        paint_m2_path [list [list $track_x $y] [list $track_x $lane]]
    }
    paint_via2 $track_x $lane 1
    return $track_x
}

proc route_bottom_pad {x y lane access_x escape_y track_x} {
    paint_rect met4 [expr {$x - 0.30}] [expr {$y - 0.30}] [expr {$x + 0.30}] [expr {$y + 0.30}]
    paint_via3 $x $y
    paint_m3_path [list [list $x $y] [list $x $escape_y]]
    if {abs($x - $access_x) > 1.0e-6} {
        paint_m3_path [list [list $x $escape_y] [list $access_x $escape_y]]
    }
    paint_via2 $access_x $escape_y
    if {abs($access_x - $track_x) > 1.0e-6} {
        paint_m3_path [list [list $access_x $escape_y] [list $track_x $escape_y]]
    }
    paint_via2 $track_x $escape_y
    if {abs($escape_y - $lane) > 1.0e-6} {
        paint_m2_path [list [list $track_x $escape_y] [list $track_x $lane]]
    }
    paint_via2 $track_x $lane 1
    return $track_x
}

proc allocate_route_track {base net} {
    global route_track_owner route_net_tracks
    if {[info exists route_net_tracks($net)]} {
        if {[llength $route_net_tracks($net)] > 0} {
            return [lindex $route_net_tracks($net) 0]
        }
    }
    set pitch 0.8
    for {set step 0} {$step < 200} {incr step} {
        if {$step == 0} {
            set candidates [list $base]
        } else {
            set delta [expr {$step * $pitch}]
            set candidates [list [expr {$base + $delta}] [expr {$base - $delta}]]
        }
        foreach candidate $candidates {
            if {$candidate < 0.25 || $candidate > 145.11} {
                continue
            }
            set blocked 0
            foreach occupied [array names route_track_owner] {
                if {abs($candidate - $occupied) < 0.65} {
                    set blocked 1
                    break
                }
            }
            if {!$blocked} {
                set route_track_owner([format %.3f $candidate]) $net
                lappend route_net_tracks($net) $candidate
                return $candidate
            }
        }
    }
    error "No routing track available for $net near $base"
}

proc make_power_stripe {name x} {
    box ${x}um 0um ${x}um 225.76um
    box width 1.2um
    paint met4
    label $name FreeSans 0.25um -met4
    port make
    port use [expr {$name eq "VGND" ? "ground" : "power"}]
    port class bidirectional
    port connections n s e w
}

proc top_pad_map {} {
    set pins {
        {ua[0]} SNS_A
        {ua[1]} SNS_B
        {ua[2]} GATE
        {ua[3]} CT
        {ui_in[0]} OFF
        {ui_in[1]} WAKE
        rst_n RSTN
        {uo_out[0]} PWR_ON
        {uo_out[1]} ILIM
        {uo_out[2]} FAULT
    }
    for {set i 3} {$i < 8} {incr i} {
        lappend pins [format {uo_out[%d]} $i] VGND
    }
    for {set i 0} {$i < 8} {incr i} {
        lappend pins [format {uio_out[%d]} $i] VGND
        lappend pins [format {uio_oe[%d]} $i] VGND
    }
    return $pins
}

proc collect_logic_endpoints {} {
    global logic_instance_xy
    foreach spec [top_logic_instances] {
        lassign $spec inst cell pinmap
        lassign $logic_instance_xy($inst) x y
        foreach {pin net} $pinmap {
            add_net_pin "$cell.mag" $x $y $pin $net logic
        }
    }
}

proc collect_top_pad_endpoints {} {
    global top
    foreach {pin net} [top_pad_map] {
        add_net_pin "$top.mag" 0.0 0.0 $pin $net pad
    }
}

proc route_global_nets {} {
    global endpoints res_group_global_bbox mimcap_global_bbox route_track_owner route_net_tracks
    array unset route_track_owner
    array set route_track_owner {}
    array unset route_net_tracks
    array set route_net_tracks {}
    set lanes [dict create \
        cz 211.0 VAPWR 210.25 VGND 209.5 nb 208.75 GATE 208.0 VDPWR 207.25]
    set lane_y 185.0
    set lane_pitch 0.75
    set nets [lsort [array names endpoints]]
    foreach net $nets {
        if {[dict exists $lanes $net]} {
            continue
        }
        dict set lanes $net $lane_y
        set lane_y [expr {$lane_y + $lane_pitch}]
    }
    if {$lane_y > 207.0} {
        error "Top-level signal routing lanes exceed the routing channel"
    }
    make_power_stripe VDPWR 8.28
    make_power_stripe VGND 11.04
    make_power_stripe VAPWR 13.80
    foreach net $nets {
        set lane [dict get $lanes $net]
        set min_x 1.0e9
        set max_x -1.0e9
        puts [format "Routing %s: %d endpoints at %.2f um" $net [llength $endpoints($net)] $lane]
        foreach endpoint $endpoints($net) {
            lassign $endpoint x y kind pin layer
            if {$kind eq "mos"} {
                set track_base [x_access $x $pin mos]
                set track_x [allocate_route_track $track_base $net]
                set ax [route_mos_endpoint $x $y $pin $layer $lane $track_x]
            } elseif {$kind eq "resistor"} {
                lassign $res_group_global_bbox rx1 ry1 rx2 ry2
                set track_base $x
                if {$pin in {nb GATE}} {
                    set track_base [expr {$rx2 + 1.0}]
                } elseif {$pin eq "VGND"} {
                    set track_base [expr {$rx1 - 1.0}]
                }
                set track_x [allocate_route_track $track_base $net]
                set ax [route_resistor_endpoint $x $y $pin $layer $lane $track_x]
            } elseif {$kind eq "pad" && $y < 2.0} {
                if {![regexp {^ua\[([0-3])\]$} $pin -> pad_index]} {
                    error "Unexpected bottom-edge pad $pin"
                }
                set ax [expr {137.0 + 2.0 * $pad_index}]
                set escape_y [expr {1.3 + 0.8 * $pad_index}]
                set track_x [allocate_route_track 142.5 $net]
                set ax [route_bottom_pad $x $y $lane $ax $escape_y $track_x]
            } elseif {$kind eq "capacitor"} {
                lassign $mimcap_global_bbox cx1 cy1 cx2 cy2
                set track_x [allocate_route_track [expr {$cx2 + 1.0}] "${net}_mim_$pin"]
                set ax [route_mim_endpoint $x $y $pin $lane $track_x]
            } else {
                set track_base $x
                if {$kind eq "pad" && $y > 220.0} {
                    set track_base [expr {$x < 72.0 ? 2.5 : 142.5}]
                }
                set track_x [allocate_route_track $track_base $net]
                set ax [route_metal_endpoint $x $y $layer $lane $track_x]
            }
            if {$ax < $min_x} {set min_x $ax}
            if {$ax > $max_x} {set max_x $ax}
        }
        if {$net eq "VDPWR"} {
            set min_x [expr {min($min_x, 8.28)}]
            set max_x [expr {max($max_x, 8.28)}]
        } elseif {$net eq "VGND"} {
            set min_x [expr {min($min_x, 11.04)}]
            set max_x [expr {max($max_x, 11.04)}]
        } elseif {$net eq "VAPWR"} {
            set min_x [expr {min($min_x, 13.80)}]
            set max_x [expr {max($max_x, 13.80)}]
        }
        paint_m3_path [list [list $min_x $lane] [list $max_x $lane]]
        if {$net in {VDPWR VGND VAPWR}} {
            set stripe_x [dict get [dict create VDPWR 8.28 VGND 11.04 VAPWR 13.80] $net]
            paint_via3 $stripe_x $lane
        }
    }
}

proc logic_devices {cell} {
    switch -- $cell {
        ls_inv {
            return [list \
                [list XMP p 2 0.5 Y A VPWR VPWR] \
                [list XMN n 1 0.5 Y A VGND VGND]]
        }
        ls_nor2 {
            return [list \
                [list XMPA p 2 0.5 pab A VPWR VPWR] \
                [list XMPB p 2 0.5 Y B pab VPWR] \
                [list XMNA n 1 0.5 Y A VGND VGND] \
                [list XMNB n 1 0.5 Y B VGND VGND]]
        }
        ls_nor3 {
            return [list \
                [list XMPA p 2 0.5 pab A VPWR VPWR] \
                [list XMPB p 2 0.5 pbc B pab VPWR] \
                [list XMPC p 2 0.5 Y C pbc VPWR] \
                [list XMNA n 1 0.5 Y A VGND VGND] \
                [list XMNB n 1 0.5 Y B VGND VGND] \
                [list XMNC n 1 0.5 Y C VGND VGND]]
        }
        ls_lvshift {
            return [list \
                [list XMPI p 2 0.5 ab A VDPWR VDPWR] \
                [list XMNI n 1 0.5 ab A VGND VGND] \
                [list XMNA n 4 0.5 yb A VGND VGND] \
                [list XMNB n 4 0.5 Y ab VGND VGND] \
                [list XMPA p 1 1 yb Y VAPWR VAPWR] \
                [list XMPB p 1 1 Y yb VAPWR VAPWR]]
        }
        ls_schmitt {
            return [list \
                [list XMP1 p 1 0.5 p1 A VPWR VPWR] \
                [list XMP2 p 1 0.5 yn A p1 VPWR] \
                [list XMP3 p 1 0.5 p1 yn VGND VPWR] \
                [list XMN1 n 1 0.5 n1 A VGND VGND] \
                [list XMN2 n 1 0.5 yn A n1 VGND] \
                [list XMN3 n 1 0.5 n1 yn VPWR VGND] \
                [list XMPO p 2 0.5 Y yn VPWR VPWR] \
                [list XMNO n 1 0.5 Y yn VGND VGND]]
        }
        default {
            error "Unknown logic cell $cell"
        }
    }
}

proc logic_ports {cell} {
    switch -- $cell {
        ls_inv {return {A Y VPWR VGND}}
        ls_nor2 {return {A B Y VPWR VGND}}
        ls_nor3 {return {A B C Y VPWR VGND}}
        ls_lvshift {return {A Y VAPWR VDPWR VGND}}
        ls_schmitt {return {A Y VPWR VGND}}
        default {error "Unknown logic cell $cell"}
    }
}

proc build_logic_cell {cell} {
    global top endpoints logic_cell_width logic_cell_height
    array unset endpoints
    array set endpoints {}
    file delete -force "$cell.mag"
    load $cell
    set devices [logic_devices $cell]
    set prepared {}
    set max_width 0.0
    set max_height 0.0
    set min_x 0.0
    set min_y 0.0
    set first 1
    foreach device $devices {
        lassign $device inst type w l drain gate source bulk
        set name "${cell}_${inst}"
        make_mos $cell $name $type $w $l
        set bbox [cell_bbox "$name.mag"]
        lassign $bbox x1 y1 x2 y2
        set width [expr {$x2 - $x1}]
        set height [expr {$y2 - $y1}]
        if {$width > $max_width} {set max_width $width}
        if {$height > $max_height} {set max_height $height}
        if {$first || $x1 < $min_x} {set min_x $x1}
        if {$first || $y1 < $min_y} {set min_y $y1}
        set first 0
        set pinmap [list D $drain G $gate S $source B $bulk]
        lappend prepared [list $name $pinmap $bbox]
    }
    set count [llength $prepared]
    set cols [expr {int(ceil(sqrt($count)))}]
    set col_pitch [expr {$max_width + 2.5}]
    set row_pitch [expr {$max_height + 2.5}]
    set row_shift 3.0
    set x_origin [expr {1.5 - $min_x}]
    set y_origin [expr {1.5 - $min_y}]
    set max_shape_x 0.0
    set max_device_y 0.0
    set index 0
    foreach item $prepared {
        lassign $item name pinmap bbox
        lassign $bbox x1 y1 x2 y2
        set row [expr {int($index / $cols)}]
        set col [expr {$index % $cols}]
        set x [expr {$x_origin + $col * $col_pitch + (($row % 2) * $row_shift)}]
        set y [expr {$y_origin + $row * $row_pitch}]
        place_existing_mos $name $x $y $pinmap
        set shape_right [expr {$x + $x2}]
        set shape_top [expr {$y + $y2}]
        if {$shape_right > $max_shape_x} {set max_shape_x $shape_right}
        if {$shape_top > $max_device_y} {set max_device_y $shape_top}
        incr index
    }
    set nets [lsort [array names endpoints]]
    set ports [logic_ports $cell]
    set lane_start [expr {$max_device_y + 3.0}]
    set lane_pitch 0.8
    set net_index 0
    foreach net $nets {
        set lane [expr {$lane_start + $net_index * $lane_pitch}]
        set min_track 1.0e9
        set max_track -1.0e9
        foreach endpoint $endpoints($net) {
            lassign $endpoint x y kind pin layer
            set ax [route_mos_endpoint $x $y $pin $layer $lane]
            if {$ax < $min_track} {set min_track $ax}
            if {$ax > $max_track} {set max_track $ax}
        }
        set port_index [lsearch -exact $ports $net]
        if {$port_index >= 0} {
            set port_x [expr {1.0 + 0.8 * $port_index}]
            if {$port_x < $min_track} {set min_track $port_x}
            if {$port_x > $max_track} {set max_track $port_x}
        }
        paint_rect met3 [expr {$min_track - 0.20}] [expr {$lane - 0.20}] [expr {$max_track + 0.20}] [expr {$lane + 0.20}]
        if {$port_index >= 0} {
            box ${port_x}um ${lane}um
            label $net FreeSans 0.25u -met3
            port make
            if {$net in {VPWR VAPWR VDPWR}} {
                port use power
            } elseif {$net eq "VGND"} {
                port use ground
            } else {
                port use signal
            }
            port class bidirectional
            port connections n s e w
        }
        incr net_index
    }
    set cell_width [expr {$max_shape_x + 3.0}]
    set cell_height [expr {$lane_start + ($net_index - 1) * $lane_pitch + 1.0}]
    save "$cell.mag"
    set logic_cell_width($cell) $cell_width
    set logic_cell_height($cell) $cell_height
    load $top
    return [list $cell_width $cell_height]
}

proc export_subckt {cell path} {
    load $cell
    select top cell
    gds write $path
    load $::top
}

proc top_logic_instances {} {
    return [list \
        [list XS0 ls_schmitt {A CT Y trip VPWR VAPWR VGND VGND}] \
        [list XLS0 ls_lvshift {A OFF Y off_h VAPWR VAPWR VDPWR VDPWR VGND VGND}] \
        [list XLS1 ls_lvshift {A WAKE Y wake_h VAPWR VAPWR VDPWR VDPWR VGND VGND}] \
        [list XLS2 ls_lvshift {A RSTN Y rstn_h VAPWR VAPWR VDPWR VDPWR VGND VGND}] \
        [list XI0 ls_inv {A rstn_h Y rst_h VPWR VAPWR VGND VGND}] \
        [list XN0 ls_nor3 {A wake_h B rst_h C fb Y flt VPWR VAPWR VGND VGND}] \
        [list XN1 ls_nor2 {A trip B flt Y fb VPWR VAPWR VGND VGND}] \
        [list XN2 ls_nor3 {A wake_h B rst_h C oqb Y oq VPWR VAPWR VGND VGND}] \
        [list XN3 ls_nor2 {A off_h B oq Y oqb VPWR VAPWR VGND VGND}] \
        [list XN4 ls_nor2 {A oq B flt Y en VPWR VAPWR VGND VGND}] \
        [list XI1 ls_inv {A en Y enb VPWR VAPWR VGND VGND}] \
        [list XN5 ls_nor2 {A det B enb Y ilim_h VPWR VAPWR VGND VGND}] \
        [list XI2 ls_inv {A ilim_h Y ilimb_h VPWR VAPWR VGND VGND}] \
        [list XI3 ls_inv {A flt Y fltb VPWR VAPWR VGND VGND}] \
        [list XO0 ls_inv {A enb Y PWR_ON VPWR VDPWR VGND VGND}] \
        [list XO1 ls_inv {A ilimb_h Y ILIM VPWR VDPWR VGND VGND}] \
        [list XO2 ls_inv {A fltb Y FAULT VPWR VDPWR VGND VGND}]]
}

proc top_analog_devices {} {
    return [list \
        [list XMB0 n 2 1 nb nb VGND VGND] \
        [list XMB1 n 2 1 pb nb VGND VGND] \
        [list XMB2 p 2 4 pb pb VAPWR VAPWR] \
        [list XMT n 1 1 tail nb VGND VGND] \
        [list XM1 n 20 2 d1 SNS_A tail VGND] \
        [list XM2 n 20 2 out1 SNS_B tail VGND] \
        [list XM3 p 4 2 d1 d1 VAPWR VAPWR] \
        [list XM4 p 4 2 out1 d1 VAPWR VAPWR] \
        [list XM6 p 40 1 GATE out1 VAPWR VAPWR] \
        [list XM7 n 40 1 GATE nb VGND VGND] \
        [list XMEN p 2 0.5 out1 en VAPWR VAPWR] \
        [list XMPD n 5 0.5 GATE enb VGND VGND] \
        [list XM6R p 4 1 det out1 VAPWR VAPWR] \
        [list XM7R n 8 1 det nb VGND VGND] \
        [list XMTS p 1 8 ts pb VAPWR VAPWR] \
        [list XMTSW p 1 0.5 CT ilimb_h ts VAPWR] \
        [list XMTD n 1 0.5 CT ilimb_h VGND VGND]]
}

proc place_logic_cell {cell x y} {
    box 0 0 0 0
    getcell $cell child 0 0 parent [expr {round($x * 200)}] [expr {round($y * 200)}]
}

proc place_logic_block {} {
    global logic_cell_width logic_cell_height logic_instance_xy
    array unset logic_instance_xy
    array set logic_instance_xy {}
    set x 15.0
    set y 12.0
    set row_height 0.0
    set max_bottom 0.0
    set gap_x 3.0
    set gap_y 3.0
    foreach spec [top_logic_instances] {
        lassign $spec inst cell pinmap
        set width $logic_cell_width($cell)
        set height $logic_cell_height($cell)
        if {$x + $width > 141.0} {
            set x 15.0
            set y [expr {$y + $row_height + $gap_y}]
            set row_height 0.0
        }
        if {$x + $width > 141.0 || $y + $height > 220.0} {
            error "Logic-cell placement exceeds the 1x2 tile"
        }
        place_logic_cell $cell $x $y
        set logic_instance_xy($inst) [list $x $y]
        set cell_bottom [expr {$y + $height}]
        if {$cell_bottom > $max_bottom} {set max_bottom $cell_bottom}
        set x [expr {$x + $width + $gap_x}]
        if {$height > $row_height} {set row_height $height}
    }
    return $max_bottom
}

proc place_analog_devices {logic_bottom} {
    global top endpoints
    array unset endpoints
    array set endpoints {}
    set devices [top_analog_devices]
    set prepared {}
    foreach device $devices {
        lassign $device inst type w l drain gate source bulk
        make_mos $top $inst $type $w $l
        set bbox [cell_bbox "$inst.mag"]
        set pinmap [list D $drain G $gate S $source B $bulk]
        lappend prepared [list $inst $pinmap $bbox]
    }
    set x 15.0
    set y [expr {$logic_bottom + 3.0}]
    set row_height 0.0
    set left 15.0
    set right 141.0
    set bottom 220.0
    set gap_x 2.5
    set gap_y 2.5
    foreach item $prepared {
        lassign $item inst pinmap bbox
        lassign $bbox x1 y1 x2 y2
        set width [expr {$x2 - $x1}]
        set height [expr {$y2 - $y1}]
        if {$x + $width > $right} {
            set x $left
            set y [expr {$y + $row_height + $gap_y}]
            set row_height 0.0
        }
        if {$x + $width > $right || $y + $height > $bottom} {
            error "Analog-device placement exceeds the 1x2 tile"
        }
        place_existing_mos $inst [expr {$x - $x1}] [expr {$y - $y1}] $pinmap
        set x [expr {$x + $width + $gap_x}]
        if {$height > $row_height} {set row_height $height}
    }
    return [expr {$y + $row_height}]
}

proc place_resistor_group {analog_bottom} {
    global top res_group_global_bbox
    make_res_group
    set bbox [cell_bbox res_group.mag]
    lassign $bbox x1 y1 x2 y2
    set x [expr {15.0 - $x1}]
    set y [expr {$analog_bottom + 3.0 - $y1}]
    if {$x + $x2 > 141.0 || $y + $y2 > 220.0} {
        error "Resistor-group placement exceeds the 1x2 tile"
    }
    set res_group_global_bbox [list \
        [expr {$x + $x1}] [expr {$y + $y1}] \
        [expr {$x + $x2}] [expr {$y + $y2}]]
    box 0 0 0 0
    getcell res_group child 0 0 parent [expr {round($x * 200)}] [expr {round($y * 200)}]
    foreach {pin net} {VAPWR VAPWR nb nb cz cz GATE GATE VGND VGND} {
        add_net_pin res_group.mag $x $y $pin $net resistor
    }
}

proc make_mim_cap {} {
    global top
    set cell XCC
    file delete -force "$cell.mag"
    load $cell
    box 0 0 0 0
    set params [dict merge [sky130::sky130_fd_pr__cap_mim_m3_1_defaults] \
        [dict create w 38 l 38 doports 1 term_t C1 term_b C2]]
    sky130::sky130_fd_pr__cap_mim_m3_1_draw $params
    save "$cell.mag"
    load $top
    return [cell_bbox "$cell.mag"]
}

proc place_mim_cap {analog_bottom} {
    global top mimcap_global_bbox
    set res_bbox [cell_bbox res_group.mag]
    lassign $res_bbox rx1 ry1 rx2 ry2
    set bbox [make_mim_cap]
    lassign $bbox x1 y1 x2 y2
    set x [expr {15.0 + ($rx2 - $rx1) + 3.0 - $x1}]
    set y [expr {$analog_bottom + 3.0 - $y1}]
    if {$x + $x2 > 141.0 || $y + $y2 > 220.0} {
        error "MIM-capacitor placement exceeds the 1x2 tile"
    }
    box 0 0 0 0
    getcell XCC child 0 0 parent [expr {round($x * 200)}] [expr {round($y * 200)}]
    set mimcap_global_bbox [list \
        [expr {$x + $x1}] [expr {$y + $y1}] [expr {$x + $x2}] [expr {$y + $y2}]]
    add_net_pin XCC.mag $x $y C1 out1 capacitor
    add_net_pin XCC.mag $x $y C2 cz capacitor
}

cd [file join $root mag]
file mkdir $cell_gds_dir
def read $template
cellname rename tt_um_template $top
load $top

foreach cell {ls_inv ls_nor2 ls_nor3 ls_lvshift ls_schmitt} {
    build_logic_cell $cell
    export_subckt $cell [file join $cell_gds_dir "$cell.gds"]
}

if {$layout_target eq "subckts"} {
    quit -noprompt
}

set logic_bottom [place_logic_block]
set analog_bottom $logic_bottom
if {$layout_stage in {analog resistors mim routing}} {
    set analog_bottom [place_analog_devices $logic_bottom]
}
if {$layout_stage in {resistors mim routing}} {
    place_resistor_group $analog_bottom
}
if {$layout_stage in {mim routing}} {
    place_mim_cap $analog_bottom
}
if {$layout_stage eq "routing"} {
    save "$top.mag"
    collect_logic_endpoints
    collect_top_pad_endpoints
    route_global_nets
    save "$top.mag"
} else {
    load $top
}
select top cell
save "$top.mag"
gds write $gds_path
lef write $lef_path -hide -pinonly
quit -noprompt
