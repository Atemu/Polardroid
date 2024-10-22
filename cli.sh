case "$1" in
    "install")
        "${install}"
        ;;
    "remove")
        "${remove}"
        ;;
    "ssh")
        if [ -z "${enableSsh}" ]; then
            echo SSH is disabled
            exit 1
        else
            case "$2" in
                "up")
                    "${sshUp}"
                    ;;
                "down")
                    "${sshDown}"
                    ;;
                *)
                    echo Unknown SSH command: "$2"
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
