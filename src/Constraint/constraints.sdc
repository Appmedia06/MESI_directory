create_clock -period 32.000 -name CLK -waveform {0.000 8.000} [get_ports sys_clk]

set_input_delay -clock [get_clocks CLK] -max 3.000 [get_ports sys_rst]
set_input_delay -clock [get_clocks CLK] -min 1.000 [get_ports sys_rst]

set_input_delay -clock [get_clocks CLK] -max 3.000 [get_ports CPU0_en_i]
set_input_delay -clock [get_clocks CLK] -min 1.000 [get_ports CPU0_en_i]
set_input_delay -clock [get_clocks CLK] -max 3.000 [get_ports CPU1_en_i]
set_input_delay -clock [get_clocks CLK] -min 1.000 [get_ports CPU1_en_i]

set_property PACKAGE_PIN H16 [get_ports sys_clk]
set_property PACKAGE_PIN D19 [get_ports sys_rst]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst]

set_property PACKAGE_PIN R14 [get_ports CPU0_data_en_o]
set_property PACKAGE_PIN P14 [get_ports CPU1_data_en_o]
set_property IOSTANDARD LVCMOS33 [get_ports CPU0_data_en_o]
set_property IOSTANDARD LVCMOS33 [get_ports CPU1_data_en_o]

set_output_delay -clock [get_clocks CLK] -max 10.000 [get_ports CPU0_data_en_o]
set_output_delay -clock [get_clocks CLK] -min 1.000 [get_ports CPU0_data_en_o]
set_output_delay -clock [get_clocks CLK] -max 10.000 [get_ports CPU1_data_en_o]
set_output_delay -clock [get_clocks CLK] -min 1.000 [get_ports CPU1_data_en_o]

set_property IOSTANDARD LVCMOS33 [get_ports CPU0_en_i]
set_property IOSTANDARD LVCMOS33 [get_ports CPU1_en_i]
set_property PACKAGE_PIN D20 [get_ports CPU0_en_i]
set_property PACKAGE_PIN L20 [get_ports CPU1_en_i]
