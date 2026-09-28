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

set route_guard_rects {}
array set route_guard_spacing {li 0.17 locali 0.17 met1 0.14 met2 0.14 met3 0.3 met4 0.3}
proc route_guard_reset {} {
    set ::route_guard_rects {}
}

proc route_guard_register {net layer x1 y1 x2 y2} {
    global route_guard_rects route_guard_spacing
    set xlo [expr {min($x1, $x2)}]
    set ylo [expr {min($y1, $y2)}]
    set xhi [expr {max($x1, $x2)}]
    set yhi [expr {max($y1, $y2)}]
    set spacing 0.0
    if {[info exists route_guard_spacing($layer)]} {
        set spacing $route_guard_spacing($layer)
    }
    set conflicts {}
    foreach rect $route_guard_rects {
        lassign $rect owner other_layer ox1 oy1 ox2 oy2
        if {$owner eq $net || $other_layer ne $layer} {
            continue
        }
        if {$xlo < $ox2 + $spacing && $xhi > $ox1 - $spacing &&
            $ylo < $oy2 + $spacing && $yhi > $oy1 - $spacing} {
            lappend conflicts [format "%s %s {%.3f %.3f %.3f %.3f}" \
                $owner $other_layer $ox1 $oy1 $ox2 $oy2]
        }
    }
    if {[llength $conflicts] > 0} {
        error [format "route conflict: %s %s {%.3f %.3f %.3f %.3f} spacing %.3f conflicts with %s" \
            $net $layer $xlo $ylo $xhi $yhi $spacing [join $conflicts {; }]]
    }
    lappend route_guard_rects [list $net $layer $xlo $ylo $xhi $yhi]
}

proc paint_net_rect {net layer x1 y1 x2 y2} {
    route_guard_register $net $layer $x1 $y1 $x2 $y2
    box ${x1}um ${y1}um ${x2}um ${y2}um
    paint $layer
}

proc paint_m2_path {points net} {
    set width 0.3
    for {set i 0} {$i < [expr {[llength $points] - 1}]} {incr i} {
        lassign [lindex $points $i] x1 y1
        lassign [lindex $points [expr {$i + 1}]] x2 y2
        if {abs($x1 - $x2) < 1.0e-6} {
            paint_net_rect $net met2 [expr {$x1 - $width / 2.0}] [expr {min($y1, $y2) - $width / 2.0}] \
                [expr {$x1 + $width / 2.0}] [expr {max($y1, $y2) + $width / 2.0}]
        } elseif {abs($y1 - $y2) < 1.0e-6} {
            paint_net_rect $net met2 [expr {min($x1, $x2) - $width / 2.0}] [expr {$y1 - $width / 2.0}] \
                [expr {max($x1, $x2) + $width / 2.0}] [expr {$y1 + $width / 2.0}]
        } else {
            error "M2 route is not Manhattan"
        }
    }
}

proc paint_m3_path {points net} {
    set width 0.4
    for {set i 0} {$i < [expr {[llength $points] - 1}]} {incr i} {
        lassign [lindex $points $i] x1 y1
        lassign [lindex $points [expr {$i + 1}]] x2 y2
        if {abs($x1 - $x2) < 1.0e-6} {
            paint_net_rect $net met3 [expr {$x1 - $width / 2.0}] [expr {min($y1, $y2) - $width / 2.0}] \
                [expr {$x1 + $width / 2.0}] [expr {max($y1, $y2) + $width / 2.0}]
        } elseif {abs($y1 - $y2) < 1.0e-6} {
            paint_net_rect $net met3 [expr {min($x1, $x2) - $width / 2.0}] [expr {$y1 - $width / 2.0}] \
                [expr {max($x1, $x2) + $width / 2.0}] [expr {$y1 + $width / 2.0}]
        } else {
            error "M3 route is not Manhattan"
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

proc route_res_contact {x y net} {
    paint_net_rect $net locali [expr {$x - 0.22}] [expr {$y - 0.22}] [expr {$x + 0.22}] [expr {$y + 0.22}]
    paint_net_rect $net mcon [expr {$x - 0.16}] [expr {$y - 0.16}] [expr {$x + 0.16}] [expr {$y + 0.16}]
    paint_net_rect $net met1 [expr {$x - 0.22}] [expr {$y - 0.22}] [expr {$x + 0.22}] [expr {$y + 0.22}]
    paint_via1 $net $x $y
    paint_net_rect $net met2 [expr {$x - 0.22}] [expr {$y - 0.22}] [expr {$x + 0.22}] [expr {$y + 0.22}]
}

proc route_res_body_contact {x y exit_x net} {
    paint_net_rect $net locali [expr {$x - 0.22}] [expr {$y - 0.22}] [expr {$x + 0.22}] [expr {$y + 0.22}]
    paint_net_rect $net mcon [expr {$x - 0.16}] [expr {$y - 0.16}] [expr {$x + 0.16}] [expr {$y + 0.16}]
    paint_net_rect $net met1 [expr {$x - 0.22}] [expr {$y - 0.22}] [expr {$x + 0.22}] [expr {$y + 0.22}]
    paint_net_rect $net met1 [expr {min($x, $exit_x) - 0.2}] [expr {$y - 0.2}] [expr {max($x, $exit_x) + 0.2}] [expr {$y + 0.2}]
    paint_via1 $net $exit_x $y
    paint_net_rect $net met2 [expr {$exit_x - 0.22}] [expr {$y - 0.22}] [expr {$exit_x + 0.22}] [expr {$y + 0.22}]
    paint_via2 $net $exit_x $y
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
    global top res_group_local_m3_obstacles
    route_guard_reset
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
    set r1nets {VAPWR r1 r2 r3 cz}
    set r2nets {r1 r2 r3 nb GATE}
    for {set i 0} {$i < 5} {incr i} {
        lassign [label_center "$cell.mag" "R1_$i" resistor] r1x($i) r1y($i) layer
        lassign [label_center "$cell.mag" "R2_$i" resistor] r2x($i) r2y($i) layer
        route_res_contact $r1x($i) $r1y($i) [lindex $r1nets $i]
        route_res_contact $r2x($i) $r2y($i) [lindex $r2nets $i]
    }
    lassign [label_center "$cell.mag" B resistor] bx by layer
    set body_route_x [expr {$x1 - 2.0}]
    route_res_body_contact $bx $by $body_route_x VGND
    for {set i 0} {$i < 3} {incr i} {
        set xmid [expr {($r2x($i) + $r1x([expr {$i + 1}])) / 2.0}]
        paint_m2_path [list \
            [list $r2x($i) $r2y($i)] \
            [list $xmid $r2y($i)] \
            [list $xmid $r1y([expr {$i + 1}])] \
            [list $r1x([expr {$i + 1}]) $r1y([expr {$i + 1}])]] [lindex {r1 r2 r3} $i]
    }
    set top_port_y [expr {$y2 + 7.0}]
    set nb_port_y [expr {$y1 - 7.0}]
    set gate_port_y [expr {$y1 - 8.5}]
    set body_port_y [expr {$y1 - 10.0}]
    paint_m2_path [list [list $r1x(0) $r1y(0)] [list $r1x(0) $top_port_y]] VAPWR
    paint_m2_path [list [list $r2x(3) $r2y(3)] [list $r2x(3) $nb_port_y]] nb
    paint_m2_path [list [list $r1x(4) $r1y(4)] [list $r1x(4) [expr {$top_port_y + 2.0}]]] cz
    paint_via2 GATE $r2x(4) $r2y(4)
    paint_m3_path [list [list $r2x(4) $r2y(4)] [list $r2x(4) $gate_port_y]] GATE
    paint_m3_path [list \
        [list $body_route_x $by] \
        [list $body_route_x $body_port_y]] VGND
    set res_group_local_m3_obstacles [list \
        [list GATE met3 \
            [expr {$r2x(4) - 0.2}] [expr {min($r2y(4), $gate_port_y) - 0.2}] \
            [expr {$r2x(4) + 0.2}] [expr {max($r2y(4), $gate_port_y) + 0.2}]] \
        [list VGND met3 \
            [expr {$body_route_x - 0.2}] [expr {min($by, $body_port_y) - 0.2}] \
            [expr {$body_route_x + 0.2}] [expr {max($by, $body_port_y) + 0.2}]]]
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
    return [list \
        [expr {($x1 + $x2) / 400.0}] [expr {($y1 + $y2) / 400.0}] $layer \
        [expr {$x1 / 200.0}] [expr {$y1 / 200.0}] [expr {$x2 / 200.0}] [expr {$y2 / 200.0}]]
}

array set endpoints {}
array set logic_cell_width {}
array set logic_cell_height {}
array set logic_instance_xy {}
set res_group_global_bbox {}
set mimcap_global_bbox {}
set analog_start_y 0.0
set res_group_local_m3_obstacles {}
set res_group_global_m3_obstacles {}
proc add_net_pin {path x y pin net kind} {
    global endpoints
    lassign [label_center $path $pin $kind] px py layer bx1 by1 bx2 by2
    set px [expr {$x + $px}]
    set py [expr {$y + $py}]
    route_guard_register $net $layer \
        [expr {$x + $bx1}] [expr {$y + $by1}] [expr {$x + $bx2}] [expr {$y + $by2}]
    if {$kind eq "mos"} {
        route_guard_register $net met1 \
            [expr {$px - 0.22}] [expr {$py - 0.22}] [expr {$px + 0.22}] [expr {$py + 0.22}]
    } elseif {$kind eq "capacitor" && $pin eq "C2"} {
        route_guard_register $net $layer \
            [expr {$px - 0.165}] [expr {$py - 0.165}] [expr {$px + 0.165}] [expr {$py + 0.165}]
        route_guard_register $net met3 \
            [expr {$px - 0.31}] [expr {$py - 0.20}] [expr {$px + 0.31}] [expr {$py + 0.20}]
    } elseif {$kind eq "capacitor"} {
        route_guard_register $net met3 \
            [expr {$px - 0.31}] [expr {$py - 0.20}] [expr {$px + 0.31}] [expr {$py + 0.20}]
    } elseif {$kind eq "pad"} {
        route_guard_register $net $layer \
            [expr {$px - 0.30}] [expr {$py - 0.30}] [expr {$px + 0.30}] [expr {$py + 0.30}]
    } elseif {$layer in {met1 met2 met3 met4 locali}} {
        route_guard_register $net $layer \
            [expr {$px - 0.22}] [expr {$py - 0.22}] [expr {$px + 0.22}] [expr {$py + 0.22}]
    }
    if {![info exists endpoints($net)]} {
        set endpoints($net) {}
    }
    lappend endpoints($net) [list $px $py $kind $pin $layer]
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
            D {return [expr {$x - 0.12}]}
            S {return [expr {$x + 0.12}]}
            G {return [expr {$x + 1.8}]}
            B {return [expr {$x - 1.8}]}
        }
    }
    return [expr {$x + 0.35}]
}

proc paint_via1 {net x y} {
    paint_net_rect $net met1 [expr {$x - 0.18}] [expr {$y - 0.13}] [expr {$x + 0.18}] [expr {$y + 0.13}]
    paint_net_rect $net met2 [expr {$x - 0.13}] [expr {$y - 0.18}] [expr {$x + 0.13}] [expr {$y + 0.18}]
    paint_net_rect $net via1 [expr {$x - 0.13}] [expr {$y - 0.13}] [expr {$x + 0.13}] [expr {$y + 0.13}]
    sky130::via1_draw
}

proc route_mos_endpoint {x y pin layer lane net {track_x ""}} {
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
        paint_net_rect $net locali [expr {$x - 0.18}] [expr {$y - 0.18}] [expr {$x + 0.18}] [expr {$y + 0.18}]
        paint_net_rect $net mcon [expr {$x - 0.10}] [expr {$y - 0.10}] [expr {$x + 0.10}] [expr {$y + 0.10}]
        paint_net_rect $net met1 [expr {$x - 0.13}] [expr {$y - 0.16}] [expr {$x + 0.13}] [expr {$y + 0.16}]
        box [expr {$x - 0.10}]um [expr {$y - 0.10}]um [expr {$x + 0.10}]um [expr {$y + 0.10}]um
        sky130::mcon_draw vert
    }
    if {$pin eq "G"} {
        paint_net_rect $net met1 [expr {$x - 0.08}] [expr {min($y,$ay) - 0.08}] [expr {$x + 0.08}] [expr {max($y,$ay) + 0.08}]
        paint_net_rect $net met1 [expr {min($x,$ax) - 0.08}] [expr {$ay - 0.08}] [expr {max($x,$ax) + 0.08}] [expr {$ay + 0.08}]
        paint_net_rect $net met1 [expr {$ax - 0.22}] [expr {$ay - 0.22}] [expr {$ax + 0.22}] [expr {$ay + 0.22}]
    } else {
        paint_net_rect $net met1 [expr {$x - 0.22}] [expr {$y - 0.22}] [expr {$x + 0.22}] [expr {$y + 0.22}]
        paint_net_rect $net met1 [expr {min($x,$ax) - 0.22}] [expr {$y - 0.22}] [expr {max($x,$ax) + 0.22}] [expr {$y + 0.22}]
    }
    paint_via1 $net $ax $ay
    if {$local_route} {
        paint_via2 $net $ax $ay 1
        if {abs($ay - $lane) > 1.0e-6} {
            paint_m3_path [list [list $ax $ay] [list $ax $lane]] $net
        }
        paint_via2 $net $ax $lane 1
        return $ax
    }
    paint_via2 $net $ax $ay 1
    if {abs($ay - $lane) > 1.0e-6} {
        paint_m3_path [list [list $ax $ay] [list $ax $lane]] $net
    }
    paint_via2 $net $ax $lane 1
    if {abs($ax - $track_x) > 1.0e-6} {
        paint_m2_path [list [list $ax $lane] [list $track_x $lane]] $net
    }
    paint_via2 $net $track_x $lane 1
    return $track_x
}

proc paint_via2 {net x y {wide_m3 0}} {
    paint_net_rect $net met2 [expr {$x - 0.14}] [expr {$y - 0.19}] [expr {$x + 0.14}] [expr {$y + 0.19}]
    if {$wide_m3} {
        paint_net_rect $net met3 [expr {$x - 0.31}] [expr {$y - 0.20}] [expr {$x + 0.31}] [expr {$y + 0.20}]
    } else {
        paint_net_rect $net met3 [expr {$x - 0.19}] [expr {$y - 0.165}] [expr {$x + 0.19}] [expr {$y + 0.165}]
    }
    paint_net_rect $net via2 [expr {$x - 0.14}] [expr {$y - 0.14}] [expr {$x + 0.14}] [expr {$y + 0.14}]
    sky130::via2_draw
}

proc paint_via3 {net x y} {
    paint_net_rect $net met3 [expr {$x - 0.31}] [expr {$y - 0.20}] [expr {$x + 0.31}] [expr {$y + 0.20}]
    paint_net_rect $net met4 [expr {$x - 0.165}] [expr {$y - 0.165}] [expr {$x + 0.165}] [expr {$y + 0.165}]
    paint_net_rect $net via3 [expr {$x - 0.16}] [expr {$y - 0.16}] [expr {$x + 0.16}] [expr {$y + 0.16}]
    sky130::via3_draw
}

proc route_metal_endpoint {x y layer lane track_x net} {
    if {$layer eq "met4"} {
        paint_via3 $net $x $y
    } elseif {$layer eq "met2"} {
        paint_via2 $net $x $y
    } elseif {$layer ni {met3 via3 mimcapcontact}} {
        error "Unsupported route endpoint layer $layer"
    }
    if {abs($y - $lane) > 1.0e-6} {
        paint_m3_path [list [list $x $y] [list $x $lane]] $net
    }
    paint_via2 $net $x $lane 1
    if {abs($x - $track_x) > 1.0e-6} {
        paint_m2_path [list [list $x $lane] [list $track_x $lane]] $net
    }
    paint_via2 $net $track_x $lane 1
    return $track_x
}

proc route_resistor_endpoint {x y pin layer lane track_x net} {
    if {$layer ni {met2 met3}} {
        error "Unsupported resistor endpoint layer $layer"
    }
    if {$layer eq "met2"} {
        paint_via2 $net $x $y
    }
    if {abs($y - $lane) > 1.0e-6} {
        paint_m3_path [list [list $x $y] [list $x $lane]] $net
    }
    paint_via2 $net $x $lane 1
    if {abs($x - $track_x) > 1.0e-6} {
        paint_m2_path [list [list $x $lane] [list $track_x $lane]] $net
    }
    paint_via2 $net $track_x $lane 1
    return $track_x
}

proc route_mim_endpoint {x y pin lane track_x net} {
    if {$pin eq "C2"} {
        paint_via3 $net $x $y
    } elseif {$pin ne "C1"} {
        error "Unsupported MIM terminal $pin"
    }
    if {abs($y - $lane) > 1.0e-6} {
        paint_m3_path [list [list $x $y] [list $x $lane]] $net
    }
    paint_via2 $net $x $lane 1
    if {abs($x - $track_x) > 1.0e-6} {
        paint_m2_path [list [list $x $lane] [list $track_x $lane]] $net
    }
    paint_via2 $net $track_x $lane 1
    return $track_x
}

proc route_bottom_pad {x y lane track_x net} {
    paint_via3 $net $x $y
    if {abs($y - $lane) > 1.0e-6} {
        paint_m3_path [list [list $x $y] [list $x $lane]] $net
    }
    paint_via2 $net $x $lane 1
    if {abs($x - $track_x) > 1.0e-6} {
        paint_m2_path [list [list $x $lane] [list $track_x $lane]] $net
    }
    paint_via2 $net $track_x $lane 1
    return $track_x
}

proc allocate_route_track {base net} {
    global route_track_owner route_net_tracks
    if {[info exists route_net_tracks($net)]} {
        if {[llength $route_net_tracks($net)] > 0} {
            return [lindex $route_net_tracks($net) 0]
        }
    }
    set pitch 1.0
    for {set step 0} {$step < 200} {incr step} {
        if {$step == 0} {
            set candidates [list $base]
        } else {
            set delta [expr {$step * $pitch}]
            set candidates [list [expr {$base + $delta}] [expr {$base - $delta}]]
        }
        foreach candidate $candidates {
            if {$candidate < 130.0 || $candidate > 210.0} {
                continue
            }
            set blocked 0
            foreach occupied [array names route_track_owner] {
                if {abs($candidate - $occupied) < 1.0} {
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
    paint_net_rect $name met4 [expr {$x - 0.6}] 0 [expr {$x + 0.6}] 225.76
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
    global endpoints route_track_owner route_net_tracks route_content_top
    array unset route_track_owner
    array set route_track_owner {}
    array unset route_net_tracks
    array set route_net_tracks {}
    set nets [lsort [array names endpoints]]
    set lane_start 185.0
    set lane_pitch 0.8
    if {$lane_start <= $route_content_top + 0.5} {
        error [format "Routing lanes at %.2f um overlap layout content ending at %.2f um" \
            $lane_start $route_content_top]
    }
    if {$lane_start + ([llength $nets] - 1) * $lane_pitch + 0.2 > 225.76} {
        error "Top-level signal routing lanes exceed the routing channel"
    }
    make_power_stripe VDPWR 8.28
    make_power_stripe VGND 11.04
    make_power_stripe VAPWR 13.80
    set signal_index 0
    set net_index 0
    foreach net $nets {
        set lane [expr {$lane_start + $net_index * $lane_pitch}]
        incr net_index
        if {$net in {VDPWR VGND VAPWR}} {
            set track_x [dict get [dict create VDPWR 8.28 VGND 11.04 VAPWR 13.80] $net]
        } else {
            set track_x [allocate_route_track [expr {140.0 + $signal_index}] $net]
            incr signal_index
        }
        puts [format "Routing %s: %d endpoints at %.2f um" $net [llength $endpoints($net)] $lane]
        foreach endpoint $endpoints($net) {
            lassign $endpoint x y kind pin layer
            if {$kind eq "mos"} {
                set ax [route_mos_endpoint $x $y $pin $layer $lane $net $track_x]
            } elseif {$kind eq "resistor"} {
                set ax [route_resistor_endpoint $x $y $pin $layer $lane $track_x $net]
            } elseif {$kind eq "pad" && $y < 2.0} {
                if {![regexp {^ua\[([0-3])\]$} $pin -> pad_index]} {
                    error "Unexpected bottom-edge pad $pin"
                }
                set ax [route_bottom_pad $x $y $lane $track_x $net]
            } elseif {$kind eq "capacitor"} {
                set ax [route_mim_endpoint $x $y $pin $lane $track_x $net]
            } else {
                set ax [route_metal_endpoint $x $y $layer $lane $track_x $net]
            }
        }
        set lane_left [expr {min($track_x, 88.0)}]
        set lane_right [expr {max($track_x, 88.0)}]
        paint_m2_path [list [list $lane_left $lane] [list $lane_right $lane]] $net
        paint_via2 $net $track_x $lane 1
        paint_m3_path [list [list $track_x [expr {$lane - 0.4}]] [list $track_x $lane]] $net
        if {$net in {VDPWR VGND VAPWR}} {
            set stripe_x [dict get [dict create VDPWR 8.28 VGND 11.04 VAPWR 13.80] $net]
            paint_via3 $net $stripe_x $lane
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
    route_guard_reset
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
    set cols $count
    set col_pitch [expr {$max_width + 3.5}]
    set row_pitch [expr {$max_height + 2.5}]
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
        set x [expr {$x_origin + $col * $col_pitch}]
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
            set ax [route_mos_endpoint $x $y $pin $layer $lane $net]
            if {$ax < $min_track} {set min_track $ax}
            if {$ax > $max_track} {set max_track $ax}
        }
        set port_index [lsearch -exact $ports $net]
        if {$port_index >= 0} {
            set port_x [expr {1.0 + 0.8 * $port_index}]
            if {$port_x < $min_track} {set min_track $port_x}
            if {$port_x > $max_track} {set max_track $port_x}
        }
        paint_net_rect $net met2 [expr {$min_track - 0.15}] [expr {$lane - 0.15}] [expr {$max_track + 0.15}] [expr {$lane + 0.15}]
        if {$port_index >= 0} {
            box ${port_x}um ${lane}um
            label $net FreeSans 0.25u -met2
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
        [list XMTD n 1 0.5 CT ilimb_h VGND VGND] \
        [list XMTS p 1 8 ts pb VAPWR VAPWR] \
        [list XMTSW p 1 0.5 CT ilimb_h ts VAPWR] \
        [list XMB0 n 2 1 nb nb VGND VGND] \
        [list XMB1 n 2 1 pb nb VGND VGND] \
        [list XMB2 p 2 4 pb pb VAPWR VAPWR] \
        [list XMT n 1 1 tail nb VGND VGND] \
        [list XM3 p 4 2 d1 d1 VAPWR VAPWR] \
        [list XM4 p 4 2 out1 d1 VAPWR VAPWR] \
        [list XM1 n 20 2 d1 SNS_A tail VGND] \
        [list XM2 n 20 2 out1 SNS_B tail VGND] \
        [list XM6 p 40 1 GATE out1 VAPWR VAPWR] \
        [list XM7 n 40 1 GATE nb VGND VGND] \
        [list XMEN p 2 0.5 out1 en VAPWR VAPWR] \
        [list XMPD n 5 0.5 GATE enb VGND VGND] \
        [list XM6R p 4 1 det out1 VAPWR VAPWR] \
        [list XM7R n 8 1 det nb VGND VGND]]
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
        if {$x + $width > 125.0} {
            set x 15.0
            set y [expr {$y + $row_height + $gap_y}]
            set row_height 0.0
        }
        if {$x + $width > 125.0 || $y + $height > 220.0} {
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
    global top endpoints analog_start_y
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
    set analog_start_y $y
    set row_height 0.0
    set left 15.0
    set right 130.0
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
    global top analog_start_y res_group_global_bbox res_group_local_m3_obstacles res_group_global_m3_obstacles
    make_res_group
    set bbox [cell_bbox res_group.mag]
    lassign $bbox x1 y1 x2 y2
    set x [expr {145.0 - $x1}]
    set y [expr {$analog_start_y - 5.0 - $y1}]
    if {$x + $x2 > 220.0 || $y + $y2 > 220.0} {
        error "Resistor-group placement exceeds the 1x2 tile"
    }
    set res_group_global_bbox [list \
        [expr {$x + $x1}] [expr {$y + $y1}] \
        [expr {$x + $x2}] [expr {$y + $y2}]]
    set res_group_global_m3_obstacles {}
    foreach obstacle $res_group_local_m3_obstacles {
        lassign $obstacle net layer ox1 oy1 ox2 oy2
        lappend res_group_global_m3_obstacles [list $net $layer \
            [expr {$x + $ox1}] [expr {$y + $oy1}] \
            [expr {$x + $ox2}] [expr {$y + $oy2}]]
    }
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
    global top analog_start_y mimcap_global_bbox
    set res_bbox [cell_bbox res_group.mag]
    lassign $res_bbox rx1 ry1 rx2 ry2
    set bbox [make_mim_cap]
    lassign $bbox x1 y1 x2 y2
    set x [expr {145.0 + ($rx2 - $rx1) + 3.0 - $x1}]
    set y [expr {$analog_start_y - $y1}]
    if {$x + $x2 > 220.0 || $y + $y2 > 220.0} {
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
    set route_content_top $analog_bottom
    if {[info exists res_group_global_bbox]} {
        set route_content_top [expr {max($route_content_top, [lindex $res_group_global_bbox 3])}]
    }
    if {[info exists mimcap_global_bbox]} {
        set route_content_top [expr {max($route_content_top, [lindex $mimcap_global_bbox 3])}]
    }
    save "$top.mag"
    route_guard_reset
    foreach obstacle $res_group_global_m3_obstacles {
        route_guard_register {*}$obstacle
    }
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
