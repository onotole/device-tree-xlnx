#
# (C) Copyright 2020-2022 Xilinx, Inc.
# (C) Copyright 2022 Advanced Micro Devices, Inc. All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#

proc generate {drv_handle} {
	# try to source the common tcl procs
	# assuming the order of return is based on repo priority
	foreach i [get_sw_cores device_tree] {
		set common_tcl_file "[get_property "REPOSITORY" $i]/data/common_proc.tcl"
		if {[file exists $common_tcl_file]} {
			source $common_tcl_file
			break
		}
	}
	set node [gen_peripheral_nodes $drv_handle]
	if {$node == 0} {
		return
	}
	set audio_channels [get_property CONFIG.AUDIO_CHANNELS [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,audio-channels" $audio_channels int
	set audio_enable [get_property CONFIG.AUDIO_ENABLE [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,audio-enable" $audio_enable int
	set bits_per_color [get_property CONFIG.BITS_PER_COLOR [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,bits-per-color" $bits_per_color int
	set hdcp22_enable [get_property CONFIG.HDCP22_ENABLE [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,hdcp22-enable" $hdcp22_enable int
	set hdcp_enable [get_property CONFIG.HDCP_ENABLE [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,hdcp-enable" $hdcp_enable int
	set include_fec_ports [get_property CONFIG.INCLUDE_FEC_PORTS [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,include-fec-ports" $include_fec_ports int
	lappend reg_names "dp_base" "edid_base"
	hsi::utils::add_new_dts_param "${node}" "reg-names" $reg_names stringlist
	lappend phy_names "dp-phy0" "dp-phy1" "dp-phy2" "dp-phy3"
	hsi::utils::add_new_dts_param "${node}" "phy-names" $phy_names stringlist
	set lane_count [get_property CONFIG.LANE_COUNT [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,lane-count" $lane_count int
	set i 0
	while {$i < $lane_count} {
		set phy_s "vphy_lane$i 0 1 1 0"
		set clocks [lappend clocks $phy_s]
		set updat  [lappend updat $phy_s]
		incr i
	}
	set len [llength $updat]
	switch $len {
		"1" {
			set refs [lindex $updat 0]
			hsi::utils::add_new_dts_param "${node}" "phys" "$refs" reference
		}
		"2" {
			set refs [lindex $updat 0]
			append refs ">, <&[lindex $updat 1]"
			hsi::utils::add_new_dts_param "${node}" "phys" "$refs" reference
		}
		"3" {
			set refs [lindex $updat 0]
			append refs ">, <&[lindex $updat 1]>, <&[lindex $updat 2]"
			hsi::utils::add_new_dts_param "${node}" "phys" "$refs" reference
		}
		"4" {
			set refs [lindex $updat 0]
			append refs ">, <&[lindex $updat 1]>, <&[lindex $updat 2]>, <&[lindex $updat 3]"
			hsi::utils::add_new_dts_param "${node}" "phys" "$refs" reference
		}
	}
	set link_rate [get_property CONFIG.LINK_RATE [get_cells -hier $drv_handle]]
	set link_rate [expr {${link_rate} * 1000}]
	set link_rate [expr int ($link_rate)]
	hsi::utils::add_new_dts_param "${node}" "xlnx,linkrate" $link_rate int
	set mode [get_property CONFIG.MODE [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,mode" $mode int
	set num_streams [get_property CONFIG.NUM_STREAMS [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,num-streams" $num_streams int
	set phy_data_width [get_property CONFIG.PHY_DATA_WIDTH [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,phy-data-width" $phy_data_width int
	set pixel_mode [get_property CONFIG.PIXEL_MODE [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,pixel-mode" $pixel_mode int
	set sim_mode [get_property CONFIG.SIM_MODE [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,sim-mode" $sim_mode string
	set video_interface [get_property CONFIG.VIDEO_INTERFACE [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,video-interface" $video_interface int
	set ports_node [add_or_get_dt_node -n "ports" -l dprx_ports$drv_handle -p ${node}]
	hsi::utils::add_new_dts_param "$ports_node" "#address-cells" 1 int
	hsi::utils::add_new_dts_param "$ports_node" "#size-cells" 0 int
	set port0_node [add_or_get_dt_node -n "port" -u 0 -l dprx_port$drv_handle -p $ports_node]
	hsi::utils::add_new_dts_param "$port0_node" "reg" 0 int
	set dprxip [get_connected_stream_ip [get_cells -hier $drv_handle] "m_axis_video_stream1"]
	foreach ip $dprxip {
		if {[string match -nocase [get_property IP_NAME $ip] "system_ila"]} {
			continue
		}
		set intfpins [::hsi::get_intf_pins -of_objects [get_cells -hier $ip] -filter {TYPE==MASTER || TYPE ==INITIATOR}]
		set ip_mem_handles [hsi::utils::get_ip_mem_ranges $ip]
		if {[llength $ip_mem_handles]} {
			set base [string tolower [get_property BASE_VALUE $ip_mem_handles]]
			set dp_rx_node [add_or_get_dt_node -n "endpoint" -l dprx_out$drv_handle -p $ports_node]
			gen_endpoint $drv_handle "dprx_out$drv_handle"
			hsi::utils::add_new_dts_param "$dp_rx_node" "remote-endpoint" $ip$drv_handle reference
			gen_remoteendpoint $drv_handle $ip$drv_handle
			if {[string match -nocase [get_property IP_NAME $ip] "v_frmbuf_wr"]} {
				gen_frmbuf_wr_node $ip $drv_handle
			}
		} else {
			set connectip [get_connect_ip $ip $intfpins]
			if {[llength $connectip]} {
				set sdi_rx_node [add_or_get_dt_node -n "endpoint" -l dprx_out$drv_handle -p $port_node]
				gen_endpoint $drv_handle "dprx_out$drv_handle"
				hsi::utils::add_new_dts_param "$dp_rx_node" "remote-endpoint" $connectip$drv_handle reference
				gen_remoteendpoint $drv_handle $connectip$drv_handle
				if {[string match -nocase [get_property IP_NAME $connectip] "axi_vdma"] || [string match -nocase [get_property IP_NAME $connectip] "v_frmbuf_wr"]} {
					gen_frmbuf_wr_node $connectip $drv_handle
				}
			}
		}
	}
}

proc gen_frmbuf_wr_node {outip drv_handle} {
	set dt_overlay [get_property CONFIG.dt_overlay [get_os]]
	if {$dt_overlay} {
		set bus_node "amba"
	} else {
		set bus_node "amba_pl"
	}
        set vcap [add_or_get_dt_node -n "vcap_dprx$drv_handle" -p $bus_node]
        hsi::utils::add_new_dts_param $vcap "compatible" "xlnx,video" string
        hsi::utils::add_new_dts_param $vcap "dmas" "$outip 0" reference
        hsi::utils::add_new_dts_param $vcap "dma-names" "port0" string
        set vcap_ports_node [add_or_get_dt_node -n "ports" -l vcap_ports$drv_handle -p $vcap]
        hsi::utils::add_new_dts_param "$vcap_ports_node" "#address-cells" 1 int
        hsi::utils::add_new_dts_param "$vcap_ports_node" "#size-cells" 0 int
        set vcap_port_node [add_or_get_dt_node -n "port" -l vcap_port$drv_handle -u 0 -p $vcap_ports_node]
        hsi::utils::add_new_dts_param "$vcap_port_node" "reg" 0 int
        hsi::utils::add_new_dts_param "$vcap_port_node" "direction" input string
        set vcap_in_node [add_or_get_dt_node -n "endpoint" -l $outip$drv_handle -p $vcap_port_node]
        hsi::utils::add_new_dts_param "$vcap_in_node" "remote-endpoint" dprx_out$drv_handle reference
}

