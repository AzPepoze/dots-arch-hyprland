// State
let items = [];
let currentTab = "";

// Initialize
window.addEventListener('load', () => {
    // Request items from Python
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.controller) {
        window.webkit.messageHandlers.controller.postMessage({ action: 'get_items' });
    } else {
        console.error("Python interface not found!");
    }
    
    initResizer();
});

// Called from Python
function receiveItems(data) {
    items = data;
    render();
    renderSidebar(); // Initial render of sidebar
}

function render() {
    const tabsContainer = document.getElementById('tabs-container');
    const contentContainer = document.getElementById('tab-content-container');
    
    // Save scroll position of content if possible, or just clear
    const scrollPos = contentContainer.scrollTop;
    
    tabsContainer.innerHTML = '';
    contentContainer.innerHTML = '';

    // Group items by Header (Tab) -> Group
    const structure = {};
    let lastHeader = "General";
    
    items.forEach(item => {
        if (item.type === 'header') {
            lastHeader = item.text.replace(/---/g, '').trim();
            if (!structure[lastHeader]) structure[lastHeader] = {};
        } else {
            if (!structure[lastHeader]) structure[lastHeader] = {};
            const group = item.group || "Other";
            if (!structure[lastHeader][group]) structure[lastHeader][group] = [];
            structure[lastHeader][group].push(item);
        }
    });

    // Create Tabs
    const headers = Object.keys(structure);
    if (!currentTab && headers.length > 0) currentTab = headers[0];

    headers.forEach(header => {
        const btn = document.createElement('button');
        btn.className = `tab-btn ${header === currentTab ? 'active' : ''}`;
        btn.innerText = header;
        btn.onclick = () => {
            currentTab = header;
            render();
            // Don't need to re-render sidebar on tab switch
        };
        tabsContainer.appendChild(btn);
    });

    // Render Content for Current Tab
    if (currentTab && structure[currentTab]) {
        // Create Grid Container
        const grid = document.createElement('div');
        grid.className = 'content-grid';

        const groups = structure[currentTab];
        for (const [groupName, groupItems] of Object.entries(groups)) {
            const groupCard = document.createElement('div');
            groupCard.className = 'group-card';
            
            const title = document.createElement('h3');
            title.innerText = groupName;
            groupCard.appendChild(title);

            groupItems.forEach(item => {
                const itemDiv = document.createElement('div');
                itemDiv.className = 'item';
                
                // Custom Checkbox Structure
                const label = document.createElement('label');
                label.className = 'checkbox-wrapper';
                
                const checkbox = document.createElement('input');
                checkbox.type = 'checkbox';
                checkbox.id = item._id;
                checkbox.checked = item.is_selected;
                checkbox.onchange = (e) => toggleItem(item._id, e.target.checked);

                const checkmark = document.createElement('span');
                checkmark.className = 'checkmark';

                const textSpan = document.createElement('span');
                textSpan.className = 'item-label';
                textSpan.innerText = item.text + (item.type === 'essential_laptop' ? ' (Laptop)' : '');

                label.appendChild(checkbox);
                label.appendChild(checkmark);
                label.appendChild(textSpan);
                
                itemDiv.appendChild(label);

                if (item.description) {
                    const desc = document.createElement('div');
                    desc.className = 'item-description';
                    desc.innerText = item.description;
                    itemDiv.appendChild(desc);
                }

                groupCard.appendChild(itemDiv);
            });

            grid.appendChild(groupCard);
        }
        contentContainer.appendChild(grid);
        
        // Restore scroll (if needed, though content changes)
        // contentContainer.scrollTop = scrollPos; 
    }
}

function renderSidebar() {
    const listContainer = document.getElementById('execution-list-container');
    const countBadge = document.getElementById('selected-count');
    
    listContainer.innerHTML = '';
    
    // Filter selected items, excluding headers
    const selectedItems = items.filter(i => i.is_selected && i.type !== 'header');
    
    countBadge.innerText = selectedItems.length;

    selectedItems.forEach((item, index) => {
        const itemDiv = document.createElement('div');
        itemDiv.className = 'exec-item';
        
        const indexSpan = document.createElement('span');
        indexSpan.className = 'exec-index';
        indexSpan.innerText = index + 1;
        
        const contentDiv = document.createElement('div');
        contentDiv.className = 'exec-content';
        
        const nameDiv = document.createElement('div');
        nameDiv.className = 'exec-name';
        nameDiv.innerText = item.text;
        
        // Removed Command display per request
        
        contentDiv.appendChild(nameDiv);
        itemDiv.appendChild(indexSpan);
        itemDiv.appendChild(contentDiv);
        
        listContainer.appendChild(itemDiv);
    });
}

function toggleItem(id, checked) {
    // Optimistic update
    const item = items.find(i => i._id === id);
    if (item) {
        item.is_selected = checked;
        renderSidebar(); // Update sidebar immediately
    }
    
    // Notify Python
    window.webkit.messageHandlers.controller.postMessage({ 
        action: 'update_selection', 
        id: id, 
        is_selected: checked 
    });
}

// Resizer Logic
function initResizer() {
    const resizer = document.getElementById('dragMe');
    const sidebar = document.getElementById('sidebar');
    // Ensure sidebar has an ID in HTML
    
    if (!resizer || !sidebar) return;

    let x = 0;
    let w = 0;

    const mouseDownHandler = function(e) {
        x = e.clientX;
        const sbRect = sidebar.getBoundingClientRect();
        w = sbRect.width;

        document.addEventListener('mousemove', mouseMoveHandler);
        document.addEventListener('mouseup', mouseUpHandler);
        
        // Optional: add class to body to enforce cursor
        document.body.style.cursor = 'col-resize';
        resizer.classList.add('resizing');
    };

    const mouseMoveHandler = function(e) {
        // Calculate new width (Mouse moved left = sidebar grows)
        // Since sidebar is on the right, dragging left increases width
        const dx = e.clientX - x;
        const newWidth = w - dx; // Inverted because sidebar is on right
        
        if (newWidth > 150 && newWidth < 600) { // Constraints
            sidebar.style.width = `${newWidth}px`;
        }
    };

    const mouseUpHandler = function() {
        document.removeEventListener('mousemove', mouseMoveHandler);
        document.removeEventListener('mouseup', mouseUpHandler);
        
        document.body.style.removeProperty('cursor');
        resizer.classList.remove('resizing');
    };

    resizer.addEventListener('mousedown', mouseDownHandler);
}


// Button Handlers calling Python
function pySelectEssentialPC() {
    window.webkit.messageHandlers.controller.postMessage({ action: 'select_essential' });
}

function pySelectEssentialLaptop() {
    window.webkit.messageHandlers.controller.postMessage({ action: 'select_essential_laptop' });
}

function pySelectAll() {
    window.webkit.messageHandlers.controller.postMessage({ action: 'select_all' });
}

function pyDeselectAll() {
    window.webkit.messageHandlers.controller.postMessage({ action: 'deselect_all' });
}

function pyRunInstallation() {
    window.webkit.messageHandlers.controller.postMessage({ action: 'run_installation' });
}