set -x
set -e


installR() {

	sudo yum -y update
	sudo amazon-linux-extras install -y R4
}

installRStudio() {
	wget https://download1.rstudio.org/desktop/centos7/x86_64/rstudio-1.4.1717-x86_64.rpm
	sudo yum -y localinstall ./rstudio-1.4.1717-x86_64.rpm
}
# main
# ----------------------------------------------------------------------------
main() {
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.rstudio.compute.sh: START" >&2
    installR
    installRStudio
    echo "[INFO][$(date '+%Y-%m-%d %H:%M:%S')] install.rstudio.compute.sh: STOP" >&2
}

main "$@"