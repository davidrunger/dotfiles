# [m]ake and [c]hange into a [d]irectory.
# `mcd` must remain a function because an executable script cannot change the
# caller's working directory.
mcd() { mkdir $1 && cd $1; }
