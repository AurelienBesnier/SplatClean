echo "this is in the bash script: $HOME"
eval "$(mamba shell hook --shell bash)"

mamba activate splat

cwltool -h
