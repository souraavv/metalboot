WATCOM_ROOT="/Users/sourav/Downloads/open-watcom-v2/rel"

if [[ ! -d "$WATCOM_ROOT" ]]; then
    echo "Error: Directory not found at $WATCOM_ROOT"
    return 1 2>/dev/null
fi

export WATCOM="$WATCOM_ROOT"
export PATH="$WATCOM/armo64:$WATCOM/bino64:$PATH"
export INCLUDE="$WATCOM/h"
export EDDAT="$WATCOM/eddat"

echo "Open Watcom v2 initialized successfully."
