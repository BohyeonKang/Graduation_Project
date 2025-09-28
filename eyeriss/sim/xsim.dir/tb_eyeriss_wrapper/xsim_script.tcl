set_param project.enableReportConfiguration 0
load_feature core
current_fileset
xsim {tb_eyeriss_wrapper} -wdb {simulate_xsim_tb_eyeriss_wrapper.wdb} -autoloadwcfg
