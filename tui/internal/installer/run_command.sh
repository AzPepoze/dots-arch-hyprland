
run_command() {
    local command_to_run="$1"
    echo -e "\n\e[1;34m--- Running: ${command_to_run} ---\e[0m"
    while true; do
        eval "${command_to_run}"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo -e "\n\e[1;32m--- Finished: ${command_to_run} ---\e[0m"
            return 0
        else
            echo -e "\n\e[1;31m--- ERROR: Command \"${command_to_run}\" failed with exit code $exit_code. ---\e[0m"
            read -p "      [R]retry, [I]gnore, or [A]bort? " choice
            case "$choice" in
                [rR]) echo -e "\n\e[1;33m--- Retrying... ---\e[0m"; continue ;; 
                [iI]) echo -e "\n\e[1;33m--- Ignoring... ---\e[0m"; return 0 ;; 
                [aA]) echo -e "\n\e[1;31m--- Aborting. ---\e[0m"; exit 1 ;; 
                *) echo -e "\n\e[1;33m--- Retrying... ---\e[0m"; continue ;; 
            esac
        fi
    done
}
