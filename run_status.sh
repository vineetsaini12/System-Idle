#!/bin/bash

sudo touch /home/gor/f.txt
sudo chmod 777 /home/gor/f.txt

echo "Content-type: text/html"
echo ""

erts_version=$(grep 'ERTS_VSN' /opt/butler_server/bin/butler_server | head -n 1 | cut -d '"' -f2)

# Run the script
sudo /opt/butler_server/erts-"$erts_version"/bin/escript /home/gor/SystemIdle/data.escript > /home/gor/SystemIdleExecution.txt 2>&1

# Define Groups
declare -A groups
groups["STATIONS"]="ACTIVE-STATIONS CLOSED-STATIONS"
groups["PICK"]="PICK-BINS PICK-INSTRUCTIONS TOTES-ATTACHED-BINS"
groups["PUT"]="PUT-BINS PUT-OUTPUTS"
groups["AUDIT"]="IN-PROGRESS-AUDITS PENDING-APPROVAL-AUDITS PAUSED-AUDITS CREATED-AUDITS PENDING-AUDIT-LINES"
groups["ORDERS"]="PENDING-ORDERS INVENTORY-AWAITED-ORDERS CREATED-ORDERS"
groups["DATA_SANITY"]="DataSanity-MHS DataSanity-DOMAIN"
groups["TASKS"]="PPS-TASKS AUDIT-TASKS POST-PICK-TASKS MOVE-TASKS"
groups["PPS-BARCODES"]="PPS-QUEUE-BUTLERS PPS-QUEUE-RACKS RACK-STORABLE"
groups["CRONS"]="SCHEDULED-JOBS"

# Generate Grouped Data
DIR="/home/gor/SystemIdle/texts/"
echo "<div class='group-container'>"

for group in "${!groups[@]}"; do
    echo "<details class='group'>"
    echo "  <summary class='group-summary'>$group</summary>"
    echo "  <div id='$group' class='group-content'>"
    echo "    <table><tr><th>CHECKLIST</th><th>STATUS</th><th>DETAILS</th></tr>"

    for file in ${groups[$group]}; do
        filepath="$DIR/$file"
        [[ -f "$filepath" ]] || continue
        content=$(cat "$filepath" 2>/dev/null)
        first_line=$(head -n1 "$filepath")

        # Determine Status
        if [[ ! -s "$filepath" ]] || [[ "$first_line" == "Count = 0" ]] || [[ "$content" == "Data = true" ]] || [[ "$content" == "Data = [{data_domain,{result,true}},{data_sanity,{result,true}}]" ]]; then
            status="<span class='tick'>&#10004;</span>"
            info=""
        else
            escaped_content=$(cat "$filepath" | sed ':a;N;$!ba;s/\n/\\n/g; s/"/\\"/g; s/'\''/\\'\''/g')
            status="<span class='cross'>&#10008;</span>"
            info="<button class='info-btn' onclick='showPopup(\"$file\", \"$escaped_content\")'>Info</button>"
        fi

        echo "<tr><td>$file</td><td>$status</td><td>$info</td></tr>"
    done

    echo "    </table>"
    echo "  </div>"
    echo "</details>"
done


echo "</div>"
