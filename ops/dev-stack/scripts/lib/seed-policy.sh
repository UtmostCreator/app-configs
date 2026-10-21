run_required() {
	label=$1
	shift
	info "Required: $label"
	"$@" || die "Required seed/provisioning operation failed: $label"
	ok "$label"
}

run_optional() {
	label=$1
	shift
	info "Optional: $label"
	if "$@"; then
		ok "$label"
	else
		warn "Optional seed/provisioning operation failed: $label"
	fi
}
