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
set route_endpoint_rects {}
array set route_guard_spacing {li 0.17 locali 0.17 met1 0.14 met2 0.14 met3 0.3 met4 0.3}
proc route_guard_reset {} {
    set ::route_guard_rects {}
}

proc route_guard_conflicts {net layer x1 y1 x2 y2} {
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
    return [list $spacing [join $conflicts {; }]]
}

proc route_guard_register {net layer x1 y1 x2 y2} {
    global route_guard_rects
    set xlo [expr {min($x1, $x2)}]
    set ylo [expr {min($y1, $y2)}]
    set xhi [expr {max($x1, $x2)}]
    set yhi [expr {max($y1, $y2)}]
    lassign [route_guard_conflicts $net $layer $xlo $ylo $xhi $yhi] spacing conflicts
    if {$conflicts ne ""} {
        error [format "route conflict: %s %s {%.3f %.3f %.3f %.3f} spacing %.3f conflicts with %s" \
            $net $layer $xlo $ylo $xhi $yhi $spacing $conflicts]
    }
    lappend route_guard_rects [list $net $layer $xlo $ylo $xhi $yhi]
}

proc route_via2_shapes {x y} {
    return [list \
        [list met2 [expr {$x - 0.14}] [expr {$y - 0.19}] [expr {$x + 0.14}] [expr {$y + 0.19}]] \
        [list met3 [expr {$x - 0.31}] [expr {$y - 0.20}] [expr {$x + 0.31}] [expr {$y + 0.20}]] \
        [list via2 [expr {$x - 0.14}] [expr {$y - 0.14}] [expr {$x + 0.14}] [expr {$y + 0.14}]]]
}

proc route_via1_shapes {x y} {
    return [list \
        [list met1 [expr {$x - 0.18}] [expr {$y - 0.13}] [expr {$x + 0.18}] [expr {$y + 0.13}]] \
        [list met2 [expr {$x - 0.13}] [expr {$y - 0.18}] [expr {$x + 0.13}] [expr {$y + 0.18}]] \
        [list via1 [expr {$x - 0.13}] [expr {$y - 0.13}] [expr {$x + 0.13}] [expr {$y + 0.13}]]]
}

proc route_track_shapes {mode x args} {
    set shapes {}
    if {$mode eq "global"} {
        lassign $args lane_start lane endpoint_min endpoint_max
        lappend shapes [list met3 [expr {$x - 0.2}] [expr {$lane_start - 0.2}] \
            [expr {$x + 0.2}] [expr {$lane + 0.2}]]
        set left [expr {min($endpoint_min, $x)}]
        set right [expr {max($endpoint_max, $x)}]
        lappend shapes [list met2 [expr {$left - 0.15}] [expr {$lane - 0.15}] \
            [expr {$right + 0.15}] [expr {$lane + 0.15}]]
        lappend shapes {*}[route_via2_shapes $x $lane]
    } elseif {$mode eq "horizontal"} {
        lassign $args endpoint_min endpoint_max
        set left [expr {min($endpoint_min, $endpoint_max)}]
        set right [expr {max($endpoint_min, $endpoint_max)}]
        lappend shapes [list met2 [expr {$left - 0.15}] [expr {$x - 0.15}] \
            [expr {$right + 0.15}] [expr {$x + 0.15}]]
    } elseif {$mode eq "bottom"} {
        lassign $args source_y lane source_x
        lappend shapes [list met2 [expr {min($source_x, $x) - 0.15}] [expr {$source_y - 0.15}] \
            [expr {max($source_x, $x) + 0.15}] [expr {$source_y + 0.15}]]
        lappend shapes [list met3 [expr {$x - 0.2}] [expr {min($source_y, $lane) - 0.2}] \
            [expr {$x + 0.2}] [expr {max($source_y, $lane) + 0.2}]]
        lappend shapes {*}[route_via2_shapes $x $source_y]
        lappend shapes {*}[route_via2_shapes $x $lane]
    } elseif {$mode eq "local"} {
        lassign $args source_y lane source_x source_layer global_x
        set escape_y $source_y
        if {[llength $args] > 5} {
            set escape_y [lindex $args 5]
        }
        if {$source_layer eq "met2"} {
            if {abs($escape_y - $source_y) > 1.0e-6} {
                lappend shapes [list met2 [expr {$source_x - 0.15}] \
                    [expr {min($source_y, $escape_y) - 0.15}] \
                    [expr {$source_x + 0.15}] \
                    [expr {max($source_y, $escape_y) + 0.15}]]
                lappend shapes [list met2 [expr {min($source_x, $x) - 0.15}] \
                    [expr {$escape_y - 0.15}] \
                    [expr {max($source_x, $x) + 0.15}] \
                    [expr {$escape_y + 0.15}]]
            } else {
                lappend shapes [list met2 [expr {min($source_x, $x) - 0.15}] \
                    [expr {$source_y - 0.15}] \
                    [expr {max($source_x, $x) + 0.15}] \
                    [expr {$source_y + 0.15}]]
            }
        } elseif {$source_layer eq "met3"} {
            lappend shapes [list met3 [expr {min($source_x, $x) - 0.2}] [expr {$source_y - 0.2}] \
                [expr {max($source_x, $x) + 0.2}] [expr {$source_y + 0.2}]]
        }
        lappend shapes [list met3 [expr {$x - 0.2}] [expr {min($escape_y, $lane) - 0.2}] \
            [expr {$x + 0.2}] [expr {max($escape_y, $lane) + 0.2}]]
        lappend shapes {*}[route_via2_shapes $x $escape_y]
        lappend shapes {*}[route_via2_shapes $x $lane]
        lappend shapes [list met2 [expr {min($x, $global_x) - 0.15}] [expr {$lane - 0.15}] \
            [expr {max($x, $global_x) + 0.15}] [expr {$lane + 0.15}]]
        lappend shapes {*}[route_via2_shapes $global_x $lane]
    } elseif {$mode eq "local_m3"} {
        lassign $args source_y lane source_x source_layer global_x escape_y
        lappend shapes {*}[route_via2_shapes $source_x $source_y]
        if {abs($source_y - $escape_y) > 1.0e-6} {
            lappend shapes [list met3 [expr {$source_x - 0.2}] \
                [expr {min($source_y, $escape_y) - 0.2}] \
                [expr {$source_x + 0.2}] \
                [expr {max($source_y, $escape_y) + 0.2}]]
        }
        if {abs($source_x - $x) > 1.0e-6} {
            lappend shapes [list met3 [expr {min($source_x, $x) - 0.2}] \
                [expr {$escape_y - 0.2}] \
                [expr {max($source_x, $x) + 0.2}] \
                [expr {$escape_y + 0.2}]]
        }
        lappend shapes [list met3 [expr {$x - 0.2}] \
            [expr {min($escape_y, $lane) - 0.2}] \
            [expr {$x + 0.2}] \
            [expr {max($escape_y, $lane) + 0.2}]]
        lappend shapes {*}[route_via2_shapes $x $lane]
        lappend shapes [list met2 [expr {min($x, $global_x) - 0.15}] \
            [expr {$lane - 0.15}] \
            [expr {max($x, $global_x) + 0.15}] \
            [expr {$lane + 0.15}]]
        lappend shapes {*}[route_via2_shapes $global_x $lane]
    } elseif {$mode eq "local_m1"} {
        lassign $args source_y lane source_x source_layer global_x escape_y
        if {abs($source_y - $escape_y) > 1.0e-6} {
            lappend shapes [list met1 [expr {$source_x - 0.15}] \
                [expr {min($source_y, $escape_y) - 0.15}] \
                [expr {$source_x + 0.15}] [expr {max($source_y, $escape_y) + 0.15}]]
        }
        lappend shapes [list met1 [expr {min($source_x, $x) - 0.15}] \
            [expr {$escape_y - 0.15}] [expr {max($source_x, $x) + 0.15}] \
            [expr {$escape_y + 0.15}]]
        lappend shapes {*}[route_via1_shapes $source_x $source_y]
        lappend shapes {*}[route_via1_shapes $x $escape_y]
        lappend shapes {*}[route_via2_shapes $x $escape_y]
        lappend shapes [list met3 [expr {$x - 0.2}] \
            [expr {min($escape_y, $lane) - 0.2}] \
            [expr {$x + 0.2}] [expr {max($escape_y, $lane) + 0.2}]]
        lappend shapes {*}[route_via2_shapes $x $lane]
        lappend shapes [list met2 [expr {min($x, $global_x) - 0.15}] \
            [expr {$lane - 0.15}] [expr {max($x, $global_x) + 0.15}] \
            [expr {$lane + 0.15}]]
        lappend shapes {*}[route_via2_shapes $global_x $lane]
    } else {
        error "Unknown route-track mode $mode"
    }
    return $shapes
}

proc route_track_is_clear {net shapes} {
    global route_track_last_conflicts
    set route_track_last_conflicts {}
    foreach shape $shapes {
        lassign $shape layer x1 y1 x2 y2
        lassign [route_guard_conflicts $net $layer $x1 $y1 $x2 $y2] spacing conflicts
        if {$conflicts ne ""} {
            lappend route_track_last_conflicts [format "%s %s {%.3f %.3f %.3f %.3f}" \
                $net $layer $x1 $y1 $x2 $y2]
            lappend route_track_last_conflicts $conflicts
            return 0
        }
    }
    return 1
}

proc allocate_route_track {base net mode args} {
    global route_track_owner route_net_tracks route_m2_lane_owner route_track_last_conflicts
    if {$mode in {horizontal bottom_horizontal}} {
        lassign $args endpoint_min endpoint_max
        set pitch 0.8
        set max_y 225.56
        set last_conflicts {}
        if {$mode eq "bottom_horizontal"} {
            set max_y 10.0
        }
        for {set step 0} {$base + $step * $pitch <= $max_y} {incr step} {
            set y [expr {$base + $step * $pitch}]
            set lane_key [format "%.3f" $y]
            set blocked 0
            foreach occupied [array names route_m2_lane_owner] {
                if {$route_m2_lane_owner($occupied) ne $net &&
                    abs($y - $occupied) < $pitch - 1.0e-6} {
                    set blocked 1
                    break
                }
            }
            if {$blocked} {
                continue
            }
            set shapes [route_track_shapes horizontal $y $endpoint_min $endpoint_max]
            if {![route_track_is_clear $net $shapes]} {
                set last_conflicts $route_track_last_conflicts
                continue
            }
            set route_m2_lane_owner($lane_key) $net
            return $y
        }
        error [format "No free horizontal track remains for %s above %.2f um; last conflicts: %s" \
            $net $base [join $last_conflicts {; }]]
    }
    if {$mode in {local_escape local_escape_m3 local_escape_m1}} {
        lassign $args source_y lane source_x source_layer global_x
        set shape_mode [dict get [dict create \
            local_escape local local_escape_m3 local_m3 local_escape_m1 local_m1] $mode]
        set escape_ys [list $source_y]
        set escape_pitch 0.8
        set max_steps [expr {max(ceil((225.0 - $source_y) / $escape_pitch), \
            ceil(($source_y - 0.5) / $escape_pitch))}]
        for {set step 1} {$step <= $max_steps} {incr step} {
            foreach candidate_y [list \
                [expr {$source_y + $escape_pitch * $step}] \
                [expr {$source_y - $escape_pitch * $step}]] {
                if {$candidate_y >= 0.5 && $candidate_y <= 225.0} {
                    lappend escape_ys $candidate_y
                }
            }
        }
        set origin [expr {round($base)}]
        set last_conflicts {}
        set rejection_samples {}
        foreach escape_y $escape_ys {
            for {set offset 0} {$offset <= 145} {incr offset} {
                if {$offset == 0} {
                    set candidates [list $origin]
                } else {
                    set candidates [list [expr {$origin + $offset}] [expr {$origin - $offset}]]
                }
                foreach x $candidates {
                    if {$x < 0.31 || $x > 145.05} {
                        continue
                    }
                    set shapes [route_track_shapes $shape_mode $x $source_y $lane \
                        $source_x $source_layer $global_x $escape_y]
                    if {![route_track_is_clear $net $shapes]} {
                        set last_conflicts $route_track_last_conflicts
                        if {[llength $rejection_samples] < 4 ||
                            (abs($x - 103.0) <= 1.0e-6 &&
                             abs($escape_y - $source_y) <= 1.0e-6) ||
                            ($net eq "RSTN" && $x >= 100.0 && $x <= 104.0 &&
                             abs($escape_y - $source_y) <= 1.0e-6)} {
                            lappend rejection_samples [format "x=%.2f y=%.2f: %s" \
                                $x $escape_y [join [lrange $route_track_last_conflicts 0 5] {, }]]
                        }
                        continue
                    }
                    if {![info exists route_net_tracks($net)]} {
                        set route_net_tracks($net) {}
                    }
                    lappend route_net_tracks($net) $x
                    return [list $x $escape_y]
                }
            }
        }
        error [format "No free escaped local track remains for %s from %.3f,%.3f; last conflicts: %s; candidates: %s" \
            $net $source_x $source_y [join $last_conflicts {; }] [join $rejection_samples {; }]]
    }
    set origin [expr {round($base)}]
    set min_x 0.31
    set max_x 145.05
    if {$mode eq "global"} {
        set min_x 90.0
    } elseif {$mode eq "bottom"} {
        set max_x 7.5
    }
    set last_conflicts {}
    set rejection_samples {}
    for {set offset 0} {$offset <= 145} {incr offset} {
        if {$offset == 0} {
            set candidates [list $origin]
        } else {
            set candidates [list [expr {$origin + $offset}] [expr {$origin - $offset}]]
        }
        foreach x $candidates {
            if {$x < $min_x || $x > $max_x} {
                continue
            }
            set track_key [format "%.3f" $x]
            set blocked 0
            if {$mode eq "global"} {
                foreach occupied [array names route_track_owner] {
                    if {$route_track_owner($occupied) ne $net &&
                        abs($x - $occupied) < 1.0 - 1.0e-6} {
                        set blocked 1
                        break
                    }
                }
            }
            if {$blocked} {
                continue
            }
            set shapes [route_track_shapes $mode $x {*}$args]
            if {![route_track_is_clear $net $shapes]} {
                set last_conflicts $route_track_last_conflicts
                if {$net eq "cz" && $x >= 100.0 && $x <= 105.0 &&
                    [llength $rejection_samples] < 10} {
                    lappend rejection_samples [format "x=%.2f: %s" \
                        $x [join [lrange $route_track_last_conflicts 0 5] {, }]]
                }
                continue
            }
            if {$mode eq "global" || $mode eq "bottom"} {
                set route_track_owner($track_key) $net
            }
            if {![info exists route_net_tracks($net)]} {
                set route_net_tracks($net) {}
            }
            lappend route_net_tracks($net) $x
            return $x
        }
    }
    error [format "No free %s track remains for %s in die range %.2f..%.2f um; last conflicts: %s; candidates: %s" \
        $mode $net $min_x $max_x [join $last_conflicts {; }] [join $rejection_samples {; }]]
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
set mimcap_global_xy {}
set mimcap_global_m4_obstacle {}
set analog_start_y 0.0
set res_group_local_m3_obstacles {}
set res_group_global_m3_obstacles {}
proc add_net_pin {path x y pin net kind} {
    global endpoints route_endpoint_rects
    lassign [label_center $path $pin $kind] px py layer bx1 by1 bx2 by2
    set px [expr {$x + $px}]
    set py [expr {$y + $py}]
    set shapes [list [list $net $layer \
        [expr {$x + $bx1}] [expr {$y + $by1}] [expr {$x + $bx2}] [expr {$y + $by2}]]]
    if {$kind eq "mos"} {
        lappend shapes [list $net met1 \
            [expr {$px - 0.22}] [expr {$py - 0.22}] [expr {$px + 0.22}] [expr {$py + 0.22}]]
    } elseif {$kind eq "capacitor" && $pin eq "C2"} {
        lappend shapes [list $net $layer \
            [expr {$px - 0.165}] [expr {$py - 0.165}] [expr {$px + 0.165}] [expr {$py + 0.165}]]
    } elseif {$kind eq "capacitor"} {
        lappend shapes [list $net met3 \
            [expr {$px - 0.31}] [expr {$py - 0.20}] [expr {$px + 0.31}] [expr {$py + 0.20}]]
    } elseif {$kind eq "pad"} {
        lappend shapes [list $net $layer \
            [expr {$px - 0.30}] [expr {$py - 0.30}] [expr {$px + 0.30}] [expr {$py + 0.30}]]
    } elseif {$layer in {met1 met2 met3 met4 locali}} {
        lappend shapes [list $net $layer \
            [expr {$px - 0.22}] [expr {$py - 0.22}] [expr {$px + 0.22}] [expr {$py + 0.22}]]
    }
    foreach shape $shapes {
        route_guard_register {*}$shape
        lappend route_endpoint_rects $shape
    }
    if {![info exists endpoints($net)]} {
        set endpoints($net) {}
    }
    lappend endpoints($net) [list $px $py $kind $pin $layer]
}

proc route_guard_register_endpoint_obstacles {} {
    global route_endpoint_rects
    foreach rect $route_endpoint_rects {
        route_guard_register {*}$rect
    }
}

proc place_existing_mos {name x y pinmap} {
    box 0 0 0 0
    getcell $name child 0 0 parent ${x}um ${y}um
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
    lassign [allocate_route_track $ax $net local_escape \
        $ay $lane $ax met2 $track_x] local_track escape_y
    if {abs($ay - $escape_y) > 1.0e-6} {
        paint_m2_path [list [list $ax $ay] [list $ax $escape_y]] $net
        if {abs($ax - $local_track) > 1.0e-6} {
            paint_m2_path [list [list $ax $escape_y] [list $local_track $escape_y]] $net
        }
    } elseif {abs($ax - $local_track) > 1.0e-6} {
        paint_m2_path [list [list $ax $ay] [list $local_track $ay]] $net
    }
    paint_via2 $net $local_track $escape_y 1
    if {abs($escape_y - $lane) > 1.0e-6} {
        paint_m3_path [list [list $local_track $escape_y] [list $local_track $lane]] $net
    }
    paint_via2 $net $local_track $lane 1
    if {abs($local_track - $track_x) > 1.0e-6} {
        paint_m2_path [list [list $local_track $lane] [list $track_x $lane]] $net
    }
    paint_via2 $net $track_x $lane 1
    return $local_track
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
    if {$layer eq "met2"} {
        set source_layer met2
    } elseif {$layer in {met3 via3 mimcapcontact}} {
        set source_layer met3
    } else {
        error "Unsupported route endpoint layer $layer"
    }
    if {$source_layer eq "met2"} {
        if {[catch {
            lassign [allocate_route_track $x $net local_escape \
                $y $lane $x $source_layer $track_x] local_track escape_y
        } standard_error]} {
            puts "Standard local escape failed for $net at [format %.3f $x],[format %.3f $y]: $standard_error"
            if {![catch {
                lassign [allocate_route_track $x $net local_escape_m1 \
                    $y $lane $x $source_layer $track_x] local_track escape_y
            } m1_error]} {
                paint_via1 $net $x $y
                if {abs($y - $escape_y) > 1.0e-6} {
                    paint_net_rect $net met1 \
                        [expr {$x - 0.15}] [expr {min($y, $escape_y) - 0.15}] \
                        [expr {$x + 0.15}] [expr {max($y, $escape_y) + 0.15}]
                }
                paint_net_rect $net met1 \
                    [expr {min($x, $local_track) - 0.15}] [expr {$escape_y - 0.15}] \
                    [expr {max($x, $local_track) + 0.15}] [expr {$escape_y + 0.15}]
                paint_via1 $net $local_track $escape_y
                paint_via2 $net $local_track $escape_y 1
                if {abs($escape_y - $lane) > 1.0e-6} {
                    paint_m3_path [list [list $local_track $escape_y] [list $local_track $lane]] $net
                }
                paint_via2 $net $local_track $lane 1
                if {abs($local_track - $track_x) > 1.0e-6} {
                    paint_m2_path [list [list $local_track $lane] [list $track_x $lane]] $net
                }
                paint_via2 $net $track_x $lane 1
                return $local_track
            }
            puts "M1 local escape failed for $net: $m1_error"
            lassign [allocate_route_track $x $net local_escape_m3 \
                $y $lane $x $source_layer $track_x] local_track escape_y
            paint_via2 $net $x $y 1
            if {abs($y - $escape_y) > 1.0e-6} {
                paint_m3_path [list [list $x $y] [list $x $escape_y]] $net
            }
            if {abs($x - $local_track) > 1.0e-6} {
                paint_m3_path [list [list $x $escape_y] [list $local_track $escape_y]] $net
            }
            if {abs($escape_y - $lane) > 1.0e-6} {
                paint_m3_path [list [list $local_track $escape_y] [list $local_track $lane]] $net
            }
            paint_via2 $net $local_track $lane 1
            if {abs($local_track - $track_x) > 1.0e-6} {
                paint_m2_path [list [list $local_track $lane] [list $track_x $lane]] $net
            }
            paint_via2 $net $track_x $lane 1
            return $local_track
        }
        if {abs($y - $escape_y) > 1.0e-6} {
            paint_m2_path [list [list $x $y] [list $x $escape_y]] $net
        }
        if {abs($x - $local_track) > 1.0e-6} {
            paint_m2_path [list [list $x $escape_y] [list $local_track $escape_y]] $net
        }
        paint_via2 $net $local_track $escape_y 1
    } else {
        set local_track [allocate_route_track $x $net local \
            $y $lane $x $source_layer $track_x]
        if {abs($x - $local_track) > 1.0e-6} {
            paint_m3_path [list [list $x $y] [list $local_track $y]] $net
        }
        paint_via2 $net $local_track $y 1
    }
    set local_y [expr {$source_layer eq "met2" ? $escape_y : $y}]
    if {abs($local_y - $lane) > 1.0e-6} {
        paint_m3_path [list [list $local_track $local_y] [list $local_track $lane]] $net
    }
    paint_via2 $net $local_track $lane 1
    if {abs($local_track - $track_x) > 1.0e-6} {
        paint_m2_path [list [list $local_track $lane] [list $track_x $lane]] $net
    }
    paint_via2 $net $track_x $lane 1
    return $local_track
}

proc route_resistor_endpoint {x y pin layer lane track_x net} {
    if {$layer ni {met2 met3}} {
        error "Unsupported resistor endpoint layer $layer"
    }
    set local_track [allocate_route_track $x $net local \
        $y $lane $x $layer $track_x]
    if {abs($x - $local_track) > 1.0e-6} {
        if {$layer eq "met2"} {
            paint_m2_path [list [list $x $y] [list $local_track $y]] $net
        } else {
            paint_m3_path [list [list $x $y] [list $local_track $y]] $net
        }
    }
    paint_via2 $net $local_track $y 1
    if {abs($y - $lane) > 1.0e-6} {
        paint_m3_path [list [list $local_track $y] [list $local_track $lane]] $net
    }
    paint_via2 $net $local_track $lane 1
    if {abs($local_track - $track_x) > 1.0e-6} {
        paint_m2_path [list [list $local_track $lane] [list $track_x $lane]] $net
    }
    paint_via2 $net $track_x $lane 1
    return $local_track
}

proc allocate_mim_escape {net x y} {
    global mimcap_global_bbox res_group_global_bbox route_track_last_conflicts
    set min_x [expr {[lindex $res_group_global_bbox 2] + 0.61}]
    set max_x [expr {[lindex $mimcap_global_bbox 0] - 0.61}]
    set last_conflicts {}
    set x_candidates {}
    set candidate_x [expr {floor($max_x * 2.0) / 2.0}]
    for {} {$candidate_x >= $min_x} {set candidate_x [expr {$candidate_x - 0.5}]} {
        lappend x_candidates $candidate_x
    }
    set y_candidates [list $y]
    for {set step 1} {$step <= 160} {incr step} {
        foreach candidate_y [list [expr {$y + 0.5 * $step}] [expr {$y - 0.5 * $step}]] {
            if {$candidate_y >= 0.5 && $candidate_y <= 225.0} {
                lappend y_candidates $candidate_y
            }
        }
    }
    foreach candidate_y $y_candidates {
        foreach candidate_x $x_candidates {
            set shapes [list \
                [list met4 [expr {min($x, $candidate_x)}] [expr {$y - 0.15}] \
                    [expr {max($x, $candidate_x)}] [expr {$y + 0.15}]] \
                [list met4 [expr {$candidate_x - 0.15}] \
                    [expr {min($y, $candidate_y)}] \
                    [expr {$candidate_x + 0.15}] \
                    [expr {max($y, $candidate_y)}]] \
                [list met3 [expr {$candidate_x - 0.31}] [expr {$candidate_y - 0.20}] \
                    [expr {$candidate_x + 0.31}] [expr {$candidate_y + 0.20}]] \
                [list met4 [expr {$candidate_x - 0.165}] [expr {$candidate_y - 0.165}] \
                    [expr {$candidate_x + 0.165}] [expr {$candidate_y + 0.165}]] \
                [list via3 [expr {$candidate_x - 0.16}] [expr {$candidate_y - 0.16}] \
                    [expr {$candidate_x + 0.16}] [expr {$candidate_y + 0.16}]] \
                {*}[route_via2_shapes $candidate_x $candidate_y]]
            if {[route_track_is_clear $net $shapes]} {
                return [list $candidate_x $candidate_y]
            }
            set last_conflicts $route_track_last_conflicts
        }
    }
    error [format "No clear MIM met4 escape for %s in %.3f..%.3f um; last conflicts: %s" \
        $net $min_x $max_x [join $last_conflicts {; }]]
}

proc route_mim_endpoint {x y pin lane track_x net} {
    global mimcap_global_bbox
    if {$pin eq "C2"} {
        lassign [allocate_mim_escape $net $x $y] landing_x landing_y
        paint_net_rect $net met4 [expr {min($x, $landing_x)}] \
            [expr {$y - 0.15}] [expr {max($x, $landing_x)}] [expr {$y + 0.15}]
        if {abs($y - $landing_y) > 1.0e-6} {
            paint_net_rect $net met4 [expr {$landing_x - 0.15}] \
                [expr {min($y, $landing_y)}] [expr {$landing_x + 0.15}] \
                [expr {max($y, $landing_y)}]
        }
        paint_via3 $net $landing_x $landing_y
        set x $landing_x
        set y $landing_y
    } elseif {$pin ne "C1"} {
        error "Unsupported MIM terminal $pin"
    }
    set local_track [allocate_route_track $x $net local \
        $y $lane $x met3 $track_x]
    if {abs($x - $local_track) > 1.0e-6} {
        paint_m3_path [list [list $x $y] [list $local_track $y]] $net
    }
    paint_via2 $net $local_track $y 1
    if {abs($y - $lane) > 1.0e-6} {
        paint_m3_path [list [list $local_track $y] [list $local_track $lane]] $net
    }
    paint_via2 $net $local_track $lane 1
    if {abs($local_track - $track_x) > 1.0e-6} {
        paint_m2_path [list [list $local_track $lane] [list $track_x $lane]] $net
    }
    paint_via2 $net $track_x $lane 1
    return $local_track
}

proc route_pad_stem {x y lane net} {
    global route_track_owner
    paint_via3 $net $x $y
    if {abs($y - $lane) > 1.0e-6} {
        paint_m3_path [list [list $x $y] [list $x $lane]] $net
    }
    paint_via2 $net $x $lane 1
    set route_track_owner([format "%.3f" $x]) $net
}

proc route_bottom_pad_stem {x y lane escape_y net base} {
    paint_via3 $net $x $y
    paint_m3_path [list [list $x $y] [list $x $escape_y]] $net
    paint_via2 $net $x $escape_y 1
    set escape_x [allocate_route_track $base $net bottom $escape_y $lane $x]
    paint_m2_path [list [list $x $escape_y] [list $escape_x $escape_y]] $net
    paint_via2 $net $escape_x $escape_y 1
    paint_m3_path [list [list $escape_x $escape_y] [list $escape_x $lane]] $net
    paint_via2 $net $escape_x $lane 1
    return $escape_x
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

proc route_global_endpoint {net endpoint lane track_x} {
    lassign $endpoint x y kind pin layer
    if {$kind eq "pad"} {
        return
    } elseif {$kind eq "mos"} {
        route_mos_endpoint $x $y $pin $layer $lane $net $track_x
    } elseif {$kind eq "resistor"} {
        route_resistor_endpoint $x $y $pin $layer $lane $track_x $net
    } elseif {$kind eq "capacitor"} {
        route_mim_endpoint $x $y $pin $lane $track_x $net
    } else {
        route_metal_endpoint $x $y $layer $lane $track_x $net
    }
}

proc route_global_nets {} {
    global endpoints route_track_owner route_net_tracks route_m2_lane_owner route_content_top
    array unset route_track_owner
    array set route_track_owner {}
    array unset route_net_tracks
    array set route_net_tracks {}
    array unset route_m2_lane_owner
    array set route_m2_lane_owner {}
    set stripe_x_by_net [dict create VDPWR 8.28 VGND 11.04 VAPWR 13.80]
    foreach {net stripe_x} $stripe_x_by_net {
        set route_track_owner([format "%.3f" $stripe_x]) $net
        set route_net_tracks($net) [list $stripe_x]
    }
    set nets {}
    foreach priority {VDPWR VGND VAPWR} {
        if {[info exists endpoints($priority)]} {
            lappend nets $priority
        }
    }
    foreach net [lsort [array names endpoints]] {
        if {$net ni $nets} {
            lappend nets $net
        }
    }
    set lane_start [expr {max(185.0, ceil(($route_content_top + 0.6) / 0.8) * 0.8)}]
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
    set endpoint_bounds {}
    foreach net $nets {
        set min_x 1.0e9
        set max_x -1.0e9
        foreach endpoint $endpoints($net) {
            lassign $endpoint x y kind pin layer
            if {$x < $min_x} {set min_x $x}
            if {$x > $max_x} {set max_x $x}
        }
        dict set endpoint_bounds $net [list $min_x $max_x]
    }
    set lane_by_net {}
    set net_index 0
    foreach net $nets {
        lassign [dict get $endpoint_bounds $net] min_x max_x
        set lane [allocate_route_track [expr {$lane_start + $net_index * $lane_pitch}] \
            $net horizontal $min_x $max_x]
        dict set lane_by_net $net $lane
        incr net_index
    }
    set track_by_net {}
    foreach net $nets {
        set lane [dict get $lane_by_net $net]
        set bottom_index 0
        foreach endpoint $endpoints($net) {
            lassign $endpoint x y kind pin layer
            if {$kind eq "pad"} {
                if {$y < 2.0} {
                    if {![regexp {^ua\[([0-3])\]$} $pin -> pad_index]} {
                        error "Unexpected bottom-edge pad $pin"
                    }
                    set escape_y [allocate_route_track \
                        [expr {2.0 + 0.8 * $bottom_index}] $net bottom_horizontal \
                        [expr {min($x, 0.31)}] [expr {max($x, 7.5)}]]
                    set escape_x [route_bottom_pad_stem $x $y $lane $escape_y $net \
                        [expr {1.0 + $bottom_index}]]
                    lassign [dict get $endpoint_bounds $net] min_x max_x
                    dict set endpoint_bounds $net \
                        [list [expr {min($min_x, $escape_x)}] [expr {max($max_x, $escape_x)}]]
                    incr bottom_index
                } else {
                    route_pad_stem $x $y $lane $net
                }
            }
        }
    }
    set signal_index 0
    foreach net $nets {
        set lane [dict get $lane_by_net $net]
        if {$net in {VDPWR VGND VAPWR}} {
            set track_x [dict get $stripe_x_by_net $net]
        } else {
            lassign [dict get $endpoint_bounds $net] min_x max_x
            set track_x [allocate_route_track [expr {110.0 + $signal_index}] $net \
                global $lane_start $lane $min_x $max_x]
            incr signal_index
        }
        dict set track_by_net $net $track_x
    }
    foreach net $nets {
        set lane [dict get $lane_by_net $net]
        set track_x [dict get $track_by_net $net]
        lassign [dict get $endpoint_bounds $net] min_x max_x
        route_guard_register $net met2 \
            [expr {min($track_x, $min_x) - 0.15}] [expr {$lane - 0.15}] \
            [expr {max($track_x, $max_x) + 0.15}] [expr {$lane + 0.15}]
        route_guard_register $net met3 \
            [expr {$track_x - 0.2}] $lane_start \
            [expr {$track_x + 0.2}] $lane
        route_guard_register $net met2 \
            [expr {$track_x - 0.14}] [expr {$lane - 0.19}] \
            [expr {$track_x + 0.14}] [expr {$lane + 0.19}]
        route_guard_register $net met3 \
            [expr {$track_x - 0.31}] [expr {$lane - 0.20}] \
            [expr {$track_x + 0.31}] [expr {$lane + 0.20}]
        if {$net in {VDPWR VGND VAPWR}} {
            route_guard_register $net met4 \
                [expr {$track_x - 0.165}] [expr {$lane - 0.165}] \
                [expr {$track_x + 0.165}] [expr {$lane + 0.165}]
        }
    }
    set route_order {}
    foreach priority {WAKE OFF VDPWR VGND det VAPWR enb} {
        if {$priority in $nets} {
            lappend route_order $priority
        }
    }
    foreach net $nets {
        if {$net ni $route_order} {
            lappend route_order $net
        }
    }
    set deferred_det_endpoints {}
    foreach net $route_order {
        set lane [dict get $lane_by_net $net]
        set track_x [dict get $track_by_net $net]
        puts [format "Routing %s: %d endpoints at %.2f um on track %.2f um" \
            $net [llength $endpoints($net)] $lane $track_x]
        foreach endpoint $endpoints($net) {
            lassign $endpoint x y kind pin layer
            if {$net eq "det" && $y < 120.0} {
                lappend deferred_det_endpoints $endpoint
                continue
            }
            route_global_endpoint $net $endpoint $lane $track_x
        }
        lassign [dict get $endpoint_bounds $net] min_x max_x
        set lane_left [expr {min($track_x, $min_x)}]
        set lane_right [expr {max($track_x, $max_x)}]
        paint_m2_path [list [list $lane_left $lane] [list $lane_right $lane]] $net
        paint_via2 $net $track_x $lane 1
        paint_m3_path [list [list $track_x $lane_start] [list $track_x $lane]] $net
        if {$net in {VDPWR VGND VAPWR}} {
            paint_via3 $net $track_x $lane
        }
        if {$net eq "enb"} {
            foreach endpoint $deferred_det_endpoints {
                route_global_endpoint det $endpoint [dict get $lane_by_net det] \
                    [dict get $track_by_net det]
            }
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
    global top endpoints logic_cell_width logic_cell_height logic_cell_route_rects route_guard_rects
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
            set port_x [expr {$cell eq "ls_lvshift" && $net eq "A" ? -4.4 : 1.0 + 0.8 * $port_index}]
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
    set logic_cell_route_rects($cell) $route_guard_rects
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

proc register_logic_cell_obstacles {} {
    global logic_instance_xy logic_cell_route_rects
    foreach spec [top_logic_instances] {
        lassign $spec inst cell pinmap
        lassign $logic_instance_xy($inst) x y
        set pin_nets [dict create {*}$pinmap]
        foreach rect $logic_cell_route_rects($cell) {
            lassign $rect owner layer x1 y1 x2 y2
            if {[dict exists $pin_nets $owner]} {
                set net [dict get $pin_nets $owner]
            } else {
                set net "${inst}/$owner"
            }
            route_guard_register $net $layer \
                [expr {$x + $x1}] [expr {$y + $y1}] \
                [expr {$x + $x2}] [expr {$y + $y2}]
        }
    }
}

proc top_analog_devices {} {
    return [list \
        [list XMTSW p 1 0.5 CT ilimb_h ts VAPWR] \
        [list XMTD n 1 0.5 CT ilimb_h VGND VGND] \
        [list XMTS p 1 8 ts pb VAPWR VAPWR] \
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
    getcell $cell child 0 0 parent ${x}um ${y}um
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
        if {$inst eq "XN0"} {
            set edge_x 82.0
            set edge_y [expr {$y + 19.88}]
            if {$edge_x + $width > 145.36 || $edge_y + $height > 220.0} {
                error "XN0 placement exceeds the 1x2 tile"
            }
            place_logic_cell $cell $edge_x $edge_y
            set logic_instance_xy($inst) [list $edge_x $edge_y]
            set cell_bottom [expr {$edge_y + $height}]
            if {$cell_bottom > $max_bottom} {set max_bottom $cell_bottom}
            if {$height > $row_height} {set row_height $height}
            set x [expr {$x + $width + $gap_x}]
            continue
        }
        if {$inst eq "XN1"} {
            set edge_x 105.0
            set edge_y $y
            if {$edge_x + $width > 145.36 || $edge_y + $height > 220.0} {
                error "XN1 placement exceeds the 1x2 tile"
            }
            place_logic_cell $cell $edge_x $edge_y
            set logic_instance_xy($inst) [list $edge_x $edge_y]
            set cell_bottom [expr {$edge_y + $height}]
            if {$cell_bottom > $max_bottom} {set max_bottom $cell_bottom}
            if {$height > $row_height} {set row_height $height}
            set x [expr {$x + $width + $gap_x}]
            continue
        }
        if {$inst eq "XN3" || $inst eq "XO0"} {
            if {$inst eq "XN3"} {
                set edge_x 52.0
            } else {
                set edge_x 84.0
            }
            set edge_y 88.3
            if {$edge_x + $width > 145.36 || $edge_y + $height > 220.0} {
                error "$inst placement exceeds the 1x2 tile"
            }
            place_logic_cell $cell $edge_x $edge_y
            set logic_instance_xy($inst) [list $edge_x $edge_y]
            set cell_bottom [expr {$edge_y + $height}]
            if {$cell_bottom > $max_bottom} {set max_bottom $cell_bottom}
            if {$height > $row_height} {set row_height $height}
            set x [expr {$x + $width + $gap_x}]
            continue
        }
        if {$inst eq "XN4"} {
            set edge_x 96.0
            set edge_y 70.83
            if {$edge_x + $width > 145.36 || $edge_y + $height > 220.0} {
                error "$inst placement exceeds the 1x2 tile"
            }
            place_logic_cell $cell $edge_x $edge_y
            set logic_instance_xy($inst) [list $edge_x $edge_y]
            set cell_bottom [expr {$edge_y + $height}]
            if {$cell_bottom > $max_bottom} {set max_bottom $cell_bottom}
            if {$height > $row_height} {set row_height $height}
            set x [expr {$x + $width + $gap_x}]
            continue
        }
        if {$inst eq "XI0"} {
            set edge_x 115.0
            set edge_y 88.3
            if {$edge_x + $width > 145.36 || $edge_y + $height > 220.0} {
                error "XI0 placement exceeds the 1x2 tile"
            }
            place_logic_cell $cell $edge_x $edge_y
            set logic_instance_xy($inst) [list $edge_x $edge_y]
            set cell_bottom [expr {$edge_y + $height}]
            if {$cell_bottom > $max_bottom} {set max_bottom $cell_bottom}
            if {$height > $row_height} {set row_height $height}
            set x [expr {$x + $width + $gap_x}]
            continue
        }
        if {$inst eq "XN5"} {
            set edge_x 116.0
            set edge_y 165.0
            if {$edge_x + $width > 145.36 || $edge_y + $height > 220.0} {
                error "XN5 placement exceeds the 1x2 tile"
            }
            place_logic_cell $cell $edge_x $edge_y
            set logic_instance_xy($inst) [list $edge_x $edge_y]
            if {$height > $row_height} {set row_height $height}
            set x [expr {$x + $width + $gap_x}]
            continue
        }
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
    global top endpoints analog_start_y route_endpoint_rects
    route_guard_reset
    set route_endpoint_rects {}
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
    set right 88.0
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
    set x [expr {92.0 - $x1}]
    set y [expr {$analog_start_y - 5.0 - $y1}]
    set xlo [expr {$x + $x1}]
    set ylo [expr {$y + $y1}]
    set xhi [expr {$x + $x2}]
    set yhi [expr {$y + $y2}]
    if {$xlo < 0.0 || $ylo < 0.0 || $xhi > 145.36 || $yhi > 225.76} {
        error "Resistor-group placement exceeds the 1x2 tile"
    }
    set res_group_global_bbox [list \
        $xlo $ylo $xhi $yhi]
    set res_group_global_m3_obstacles {}
    foreach obstacle $res_group_local_m3_obstacles {
        lassign $obstacle net layer ox1 oy1 ox2 oy2
        lappend res_group_global_m3_obstacles [list $net $layer \
            [expr {$x + $ox1}] [expr {$y + $oy1}] \
            [expr {$x + $ox2}] [expr {$y + $oy2}]]
    }
    box 0 0 0 0
    getcell res_group child 0 0 parent ${x}um ${y}um
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
    global top analog_start_y mimcap_global_bbox mimcap_global_xy
    global mimcap_global_m3_obstacle mimcap_global_m4_obstacle
    set res_bbox [cell_bbox res_group.mag]
    lassign $res_bbox rx1 ry1 rx2 ry2
    set bbox [make_mim_cap]
    lassign $bbox x1 y1 x2 y2
    set x [expr {92.0 + ($rx2 - $rx1) + 3.0 - $x1}]
    set y [expr {$analog_start_y - $y1}]
    set xlo [expr {$x + $x1}]
    set ylo [expr {$y + $y1}]
    set xhi [expr {$x + $x2}]
    set yhi [expr {$y + $y2}]
    if {$xlo < 0.0 || $ylo < 0.0 || $xhi > 145.36 || $yhi > 225.76} {
        error "MIM-capacitor placement exceeds the 1x2 tile"
    }
    box 0 0 0 0
    getcell XCC child 0 0 parent ${x}um ${y}um
    set mimcap_global_bbox [list $xlo $ylo $xhi $yhi]
    set mimcap_global_xy [list $x $y]
    set mimcap_global_m3_obstacle [list out1 met3 $xlo [expr {$y + $y1}] \
        [expr {$x + 19.66}] [expr {$y + $y2}]]
    set mimcap_global_m4_obstacle [list cz met4 $xlo $ylo $xhi $yhi]
}

proc collect_mim_endpoints {} {
    global mimcap_global_xy
    lassign $mimcap_global_xy x y
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
    if {[info exists mimcap_global_m3_obstacle]} {
        route_guard_register {*}$mimcap_global_m3_obstacle
    }
    if {[info exists mimcap_global_m4_obstacle]} {
        route_guard_register {*}$mimcap_global_m4_obstacle
    }
    register_logic_cell_obstacles
    route_guard_register_endpoint_obstacles
    collect_logic_endpoints
    collect_top_pad_endpoints
    collect_mim_endpoints
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
