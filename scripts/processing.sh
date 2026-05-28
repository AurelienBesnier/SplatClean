{
	conda run -n splat filtering -s $1 -c $2
} || {

	# initialize mamba for the script
	eval "$(mamba shell hook --shell bash)"
	mamba activate splat
	filtering -s $1 -c $2
}
