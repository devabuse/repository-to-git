# Save IFS and set it to binary newline
fn_ifs_change() {
    SAVEDIFS=$IFS
    IFS=$(echo -en "\n\b")
}
# Restore IFS
fn_ifs_restore() {
    IFS=$SAVEDIFS
}
