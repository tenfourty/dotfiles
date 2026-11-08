echo hi # not a heredoc: <<EOF
echo "<<EOF in quotes"
cat <<EOF
body mentions EOF and EOFX but no opener
EOF
