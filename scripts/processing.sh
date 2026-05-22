echo "this is in the bash script: $HOME"

# initialize mamba for the script
eval "$(mamba shell hook --shell bash)"
mamba activate splat

# TODO: make a conda fallback if needed



filtering -s $1 -c $2