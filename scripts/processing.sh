{
	conda run -n splat analysis -s $1 -c $2 -n $3 --skip_filter $4 --root="$5"
} || {

	# initialize mamba for the script
	eval "$(mamba shell hook --shell bash)"
	mamba activate splat
	analysis -s $1 -c $2 -n $3 --skip_filter $4 --root="$5"
}
