# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "BANK_DEPTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BANK_NUM" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DATA_BITWIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "IFMAP_BUS_BITWIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "IFMAP_COL_ID_BITWIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "IFMAP_ROW_ID_BITWIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "NUM_COLS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "NUM_ROWS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PSUM_BUS_BITWIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PSUM_COL_ID_BITWIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PSUM_ROW_ID_BITWIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "WGHT_BUS_BITWIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "WGHT_COL_ID_BITWIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "WGHT_ROW_ID_BITWIDTH" -parent ${Page_0}


}

proc update_PARAM_VALUE.BANK_DEPTH { PARAM_VALUE.BANK_DEPTH } {
	# Procedure called to update BANK_DEPTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BANK_DEPTH { PARAM_VALUE.BANK_DEPTH } {
	# Procedure called to validate BANK_DEPTH
	return true
}

proc update_PARAM_VALUE.BANK_NUM { PARAM_VALUE.BANK_NUM } {
	# Procedure called to update BANK_NUM when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BANK_NUM { PARAM_VALUE.BANK_NUM } {
	# Procedure called to validate BANK_NUM
	return true
}

proc update_PARAM_VALUE.DATA_BITWIDTH { PARAM_VALUE.DATA_BITWIDTH } {
	# Procedure called to update DATA_BITWIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_BITWIDTH { PARAM_VALUE.DATA_BITWIDTH } {
	# Procedure called to validate DATA_BITWIDTH
	return true
}

proc update_PARAM_VALUE.IFMAP_BUS_BITWIDTH { PARAM_VALUE.IFMAP_BUS_BITWIDTH } {
	# Procedure called to update IFMAP_BUS_BITWIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IFMAP_BUS_BITWIDTH { PARAM_VALUE.IFMAP_BUS_BITWIDTH } {
	# Procedure called to validate IFMAP_BUS_BITWIDTH
	return true
}

proc update_PARAM_VALUE.IFMAP_COL_ID_BITWIDTH { PARAM_VALUE.IFMAP_COL_ID_BITWIDTH } {
	# Procedure called to update IFMAP_COL_ID_BITWIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IFMAP_COL_ID_BITWIDTH { PARAM_VALUE.IFMAP_COL_ID_BITWIDTH } {
	# Procedure called to validate IFMAP_COL_ID_BITWIDTH
	return true
}

proc update_PARAM_VALUE.IFMAP_ROW_ID_BITWIDTH { PARAM_VALUE.IFMAP_ROW_ID_BITWIDTH } {
	# Procedure called to update IFMAP_ROW_ID_BITWIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IFMAP_ROW_ID_BITWIDTH { PARAM_VALUE.IFMAP_ROW_ID_BITWIDTH } {
	# Procedure called to validate IFMAP_ROW_ID_BITWIDTH
	return true
}

proc update_PARAM_VALUE.NUM_COLS { PARAM_VALUE.NUM_COLS } {
	# Procedure called to update NUM_COLS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.NUM_COLS { PARAM_VALUE.NUM_COLS } {
	# Procedure called to validate NUM_COLS
	return true
}

proc update_PARAM_VALUE.NUM_ROWS { PARAM_VALUE.NUM_ROWS } {
	# Procedure called to update NUM_ROWS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.NUM_ROWS { PARAM_VALUE.NUM_ROWS } {
	# Procedure called to validate NUM_ROWS
	return true
}

proc update_PARAM_VALUE.PSUM_BUS_BITWIDTH { PARAM_VALUE.PSUM_BUS_BITWIDTH } {
	# Procedure called to update PSUM_BUS_BITWIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PSUM_BUS_BITWIDTH { PARAM_VALUE.PSUM_BUS_BITWIDTH } {
	# Procedure called to validate PSUM_BUS_BITWIDTH
	return true
}

proc update_PARAM_VALUE.PSUM_COL_ID_BITWIDTH { PARAM_VALUE.PSUM_COL_ID_BITWIDTH } {
	# Procedure called to update PSUM_COL_ID_BITWIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PSUM_COL_ID_BITWIDTH { PARAM_VALUE.PSUM_COL_ID_BITWIDTH } {
	# Procedure called to validate PSUM_COL_ID_BITWIDTH
	return true
}

proc update_PARAM_VALUE.PSUM_ROW_ID_BITWIDTH { PARAM_VALUE.PSUM_ROW_ID_BITWIDTH } {
	# Procedure called to update PSUM_ROW_ID_BITWIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PSUM_ROW_ID_BITWIDTH { PARAM_VALUE.PSUM_ROW_ID_BITWIDTH } {
	# Procedure called to validate PSUM_ROW_ID_BITWIDTH
	return true
}

proc update_PARAM_VALUE.WGHT_BUS_BITWIDTH { PARAM_VALUE.WGHT_BUS_BITWIDTH } {
	# Procedure called to update WGHT_BUS_BITWIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.WGHT_BUS_BITWIDTH { PARAM_VALUE.WGHT_BUS_BITWIDTH } {
	# Procedure called to validate WGHT_BUS_BITWIDTH
	return true
}

proc update_PARAM_VALUE.WGHT_COL_ID_BITWIDTH { PARAM_VALUE.WGHT_COL_ID_BITWIDTH } {
	# Procedure called to update WGHT_COL_ID_BITWIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.WGHT_COL_ID_BITWIDTH { PARAM_VALUE.WGHT_COL_ID_BITWIDTH } {
	# Procedure called to validate WGHT_COL_ID_BITWIDTH
	return true
}

proc update_PARAM_VALUE.WGHT_ROW_ID_BITWIDTH { PARAM_VALUE.WGHT_ROW_ID_BITWIDTH } {
	# Procedure called to update WGHT_ROW_ID_BITWIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.WGHT_ROW_ID_BITWIDTH { PARAM_VALUE.WGHT_ROW_ID_BITWIDTH } {
	# Procedure called to validate WGHT_ROW_ID_BITWIDTH
	return true
}


proc update_MODELPARAM_VALUE.BANK_NUM { MODELPARAM_VALUE.BANK_NUM PARAM_VALUE.BANK_NUM } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BANK_NUM}] ${MODELPARAM_VALUE.BANK_NUM}
}

proc update_MODELPARAM_VALUE.BANK_DEPTH { MODELPARAM_VALUE.BANK_DEPTH PARAM_VALUE.BANK_DEPTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BANK_DEPTH}] ${MODELPARAM_VALUE.BANK_DEPTH}
}

proc update_MODELPARAM_VALUE.DATA_BITWIDTH { MODELPARAM_VALUE.DATA_BITWIDTH PARAM_VALUE.DATA_BITWIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_BITWIDTH}] ${MODELPARAM_VALUE.DATA_BITWIDTH}
}

proc update_MODELPARAM_VALUE.NUM_ROWS { MODELPARAM_VALUE.NUM_ROWS PARAM_VALUE.NUM_ROWS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.NUM_ROWS}] ${MODELPARAM_VALUE.NUM_ROWS}
}

proc update_MODELPARAM_VALUE.NUM_COLS { MODELPARAM_VALUE.NUM_COLS PARAM_VALUE.NUM_COLS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.NUM_COLS}] ${MODELPARAM_VALUE.NUM_COLS}
}

proc update_MODELPARAM_VALUE.IFMAP_ROW_ID_BITWIDTH { MODELPARAM_VALUE.IFMAP_ROW_ID_BITWIDTH PARAM_VALUE.IFMAP_ROW_ID_BITWIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IFMAP_ROW_ID_BITWIDTH}] ${MODELPARAM_VALUE.IFMAP_ROW_ID_BITWIDTH}
}

proc update_MODELPARAM_VALUE.WGHT_ROW_ID_BITWIDTH { MODELPARAM_VALUE.WGHT_ROW_ID_BITWIDTH PARAM_VALUE.WGHT_ROW_ID_BITWIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.WGHT_ROW_ID_BITWIDTH}] ${MODELPARAM_VALUE.WGHT_ROW_ID_BITWIDTH}
}

proc update_MODELPARAM_VALUE.PSUM_ROW_ID_BITWIDTH { MODELPARAM_VALUE.PSUM_ROW_ID_BITWIDTH PARAM_VALUE.PSUM_ROW_ID_BITWIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PSUM_ROW_ID_BITWIDTH}] ${MODELPARAM_VALUE.PSUM_ROW_ID_BITWIDTH}
}

proc update_MODELPARAM_VALUE.IFMAP_COL_ID_BITWIDTH { MODELPARAM_VALUE.IFMAP_COL_ID_BITWIDTH PARAM_VALUE.IFMAP_COL_ID_BITWIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IFMAP_COL_ID_BITWIDTH}] ${MODELPARAM_VALUE.IFMAP_COL_ID_BITWIDTH}
}

proc update_MODELPARAM_VALUE.WGHT_COL_ID_BITWIDTH { MODELPARAM_VALUE.WGHT_COL_ID_BITWIDTH PARAM_VALUE.WGHT_COL_ID_BITWIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.WGHT_COL_ID_BITWIDTH}] ${MODELPARAM_VALUE.WGHT_COL_ID_BITWIDTH}
}

proc update_MODELPARAM_VALUE.PSUM_COL_ID_BITWIDTH { MODELPARAM_VALUE.PSUM_COL_ID_BITWIDTH PARAM_VALUE.PSUM_COL_ID_BITWIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PSUM_COL_ID_BITWIDTH}] ${MODELPARAM_VALUE.PSUM_COL_ID_BITWIDTH}
}

proc update_MODELPARAM_VALUE.IFMAP_BUS_BITWIDTH { MODELPARAM_VALUE.IFMAP_BUS_BITWIDTH PARAM_VALUE.IFMAP_BUS_BITWIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IFMAP_BUS_BITWIDTH}] ${MODELPARAM_VALUE.IFMAP_BUS_BITWIDTH}
}

proc update_MODELPARAM_VALUE.WGHT_BUS_BITWIDTH { MODELPARAM_VALUE.WGHT_BUS_BITWIDTH PARAM_VALUE.WGHT_BUS_BITWIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.WGHT_BUS_BITWIDTH}] ${MODELPARAM_VALUE.WGHT_BUS_BITWIDTH}
}

proc update_MODELPARAM_VALUE.PSUM_BUS_BITWIDTH { MODELPARAM_VALUE.PSUM_BUS_BITWIDTH PARAM_VALUE.PSUM_BUS_BITWIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PSUM_BUS_BITWIDTH}] ${MODELPARAM_VALUE.PSUM_BUS_BITWIDTH}
}

