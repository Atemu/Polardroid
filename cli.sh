case "$1" in
    "install")
        "${install}"
        ;;
    "remove")
        "${remove}"
        ;;
    "rsh")
        if [ -z "${enableRsh}" ]; then
            echo RSH is disabled
            exit 1
        else
            case "$2" in
                "up")
                    "${rshUp}"
                    ;;
                "down")
                    "${rshDown}"
                    ;;
                *)
                    echo Unknown RSH command: "$2"
                    exit 1
                    ;;
            esac
        fi
        ;;
    *)
        echo Unknown command: "$1"
        exit 1
        ;;
esac
