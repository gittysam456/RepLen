let currentAction = 'add';
let walletConnected = false;

function connectWallet() {
    const btn = document.getElementById('walletBtn');
    const btnText = document.getElementById('walletText');
    
    if (walletConnected) {
        walletConnected = false;
        btn.classList.remove('connected');
        btnText.textContent = 'Connect Wallet';
        showNotification('Wallet disconnected', 'info');
        return;
    }
    
    document.getElementById('walletModal').classList.add('active');
}

function closeWalletModal() {
    document.getElementById('walletModal').classList.remove('active');
}

/**
 * Connect MetaMask wallet
 */
async function connectMetaMask() {
    const btn = document.getElementById('walletBtn');
    const btnText = document.getElementById('walletText');
    
    // Check if MetaMask is installed
    if (typeof window.ethereum !== 'undefined') {
        try {
            closeWalletModal();
            btnText.innerHTML = '<div class="loading"></div>';
            
            // Request account access
            const accounts = await window.ethereum.request({ 
                method: 'eth_requestAccounts' 
            });
            
            walletConnected = true;
            btn.classList.add('connected');
            
            const address = accounts[0];
            const shortAddress = address.slice(0, 6) + '...' + address.slice(-4);
            btnText.textContent = shortAddress;
            
            showNotification('MetaMask connected successfully!', 'success');
            updateStats();
        } catch (error) {
            console.error('Error connecting wallet:', error);
            btnText.textContent = 'Connect Wallet';
            if (error.code === 4001) {
                showNotification('Connection request rejected', 'error');
            } else {
                showNotification('Failed to connect wallet', 'error');
            }
        }
    } else {
        closeWalletModal();
        showNotification('Please install MetaMask extension', 'error');
        setTimeout(() => {
            window.open('https://metamask.io/download/', '_blank');
        }, 1000);
    }
}


 // Connect WalletConnect
async function connectWalletConnect() {
    closeWalletModal();
    showNotification('WalletConnect integration coming soon', 'info');
}

 // Connect Coinbase Wallet
async function connectCoinbase() {
    closeWalletModal();
    showNotification('Coinbase Wallet integration coming soon', 'info');
}


window.onclick = function(event) {
    const modal = document.getElementById('walletModal');
    if (event.target === modal) {
        closeWalletModal();
    }
}

function setAction(action) {
    currentAction = action;
    
    document.querySelectorAll('.action-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    event.target.classList.add('active');
}

async function submitIntent() {
    if (!walletConnected) {
        showNotification('Please connect your wallet first', 'error');
        return;
    }

    const tokenA = document.getElementById('tokenA').value;
    const tokenB = document.getElementById('tokenB').value;
    const amount = document.getElementById('amount').value;

    if (!tokenA || !tokenB || !amount) {
        showNotification('Please fill all fields', 'error');
        return;
    }

    const submitBtn = document.querySelector('.submit-btn');
    const submitText = document.getElementById('submitText');
    const submitLoading = document.getElementById('submitLoading');

    submitText.classList.add('hidden');
    submitLoading.classList.remove('hidden');
    submitBtn.disabled = true;

    setTimeout(() => {
        submitText.classList.remove('hidden');
        submitLoading.classList.add('hidden');
        submitBtn.disabled = false;

        showNotification(
            `${currentAction.charAt(0).toUpperCase() + currentAction.slice(1)} intent submitted successfully!`, 
            'success'
        );
        
        document.getElementById('tokenA').value = '';
        document.getElementById('tokenB').value = '';
        document.getElementById('amount').value = '';

        updateStats();
    }, 2000);
}

function updateStats() {
    const totalLiq = document.getElementById('totalLiquidity');
    const activeHooks = document.getElementById('activeHooks');
    const savedMEV = document.getElementById('savedFromMEV');

    animateValue(totalLiq, 0, 1250000, 1500);
    animateValue(activeHooks, 0, 42, 1500);
    animateValue(savedMEV, 0, 85000, 1500);
}

function animateValue(element, start, end, duration) {
    const range = end - start;
    const increment = range / (duration / 16);
    let current = start;

    const timer = setInterval(() => {
        current += increment;
        if (current >= end) {
            current = end;
            clearInterval(timer);
        }
        
        if (element.id === 'activeHooks') {
            element.textContent = Math.floor(current);
        } else {
            element.textContent = '$' + Math.floor(current).toLocaleString();
        }
    }, 16);
}

function showNotification(message, type) {
    const notification = document.createElement('div');
    notification.style.cssText = `
        position: fixed;
        top: 100px;
        right: 20px;
        padding: 1rem 2rem;
        background: ${type === 'success' ? '#10B981' : type === 'error' ? '#EF4444' : '#3B82F6'};
        color: white;
        border-radius: 12px;
        box-shadow: 0 8px 24px rgba(0,0,0,0.2);
        z-index: 1000;
        font-family: 'Space Mono', monospace;
        font-weight: 700;
        animation: slideInRight 0.3s ease;
    `;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.style.animation = 'slideOutRight 0.3s ease';
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

window.addEventListener('load', () => {
    setTimeout(() => {
        document.getElementById('totalLiquidity').textContent = '$0';
        document.getElementById('activeHooks').textContent = '0';
        document.getElementById('savedFromMEV').textContent = '$0';
    }, 100);
});

function switchTab(tabName) {
    // Remove active class from all tabs and content
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });
    
    event.target.classList.add('active');
    document.getElementById(tabName).classList.add('active');
}

// Interactive Demo Variables
let demoConfig = {
    actionType: 'ADD_LIQUIDITY',
    amount: 10000,
    delay: 5,
    steps: 10,
    isSimulating: false,
    currentBlock: 0,
    interval: null
};

function setActionType(type) {
    if (demoConfig.isSimulating) return;
    
    demoConfig.actionType = type;
    
    document.querySelectorAll('.action-type-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    document.querySelector(`[data-action="${type}"]`).classList.add('active');
}

function updateAmount(value) {
    demoConfig.amount = parseInt(value);
    document.getElementById('amountDisplay').textContent = '$' + parseInt(value).toLocaleString();
    
    if (!demoConfig.isSimulating) {
        document.getElementById('bufferedLiquidity').textContent = '$' + parseInt(value).toLocaleString();
    }
}

 //Update delay 
function updateDelay(value) {
    demoConfig.delay = parseInt(value);
    document.getElementById('delayDisplay').textContent = value;
    updateLeakageInfo();
}

function updateSteps(value) {
    demoConfig.steps = parseInt(value);
    document.getElementById('stepsDisplay').textContent = value;
    updateLeakageInfo();
}

function updateLeakageInfo() {
    const totalBlocks = demoConfig.delay + demoConfig.steps;
    document.getElementById('leakageInfo').textContent = 
        `${totalBlocks} blocks of obfuscation reduce exploitability compared to instant execution`;
}

function runSimulation() {
    if (demoConfig.isSimulating) return;
    
    demoConfig.isSimulating = true;
    demoConfig.currentBlock = 0;
    
    document.querySelectorAll('.action-type-btn, .range-slider').forEach(el => {
        el.disabled = true;
    });
    
    const runBtn = document.getElementById('runBtn');
    runBtn.disabled = true;
    runBtn.textContent = 'Simulating...';
    
    // Reset values
    document.getElementById('activeLiquidity').textContent = '$0';
    document.getElementById('activePercent').textContent = '0% activated';
    document.getElementById('bufferedLiquidity').textContent = '$' + demoConfig.amount.toLocaleString();
    document.getElementById('bufferedPercent').textContent = '100% pending';
    
    demoConfig.interval = setInterval(() => {
        demoConfig.currentBlock++;
        updateSimulationUI();
        
        if (demoConfig.currentBlock >= demoConfig.delay + demoConfig.steps) {
            clearInterval(demoConfig.interval);
            demoConfig.isSimulating = false;
            
            document.querySelectorAll('.action-type-btn, .range-slider').forEach(el => {
                el.disabled = false;
            });
            runBtn.disabled = false;
            runBtn.textContent = 'Run Simulation';
        }
    }, 300);
}

function updateSimulationUI() {
    const { currentBlock, delay, steps, amount } = demoConfig;
    
    document.getElementById('currentBlock').textContent = currentBlock;
    
    const totalBlocks = delay + steps;
    const progress = Math.min((currentBlock / totalBlocks) * 100, 100);
    document.getElementById('progressBar').style.width = progress + '%';
    
    let activeAmount = 0;
    if (currentBlock > delay) {
        const smoothingProgress = Math.min((currentBlock - delay) / steps, 1);
        activeAmount = amount * smoothingProgress;
    }
    const bufferedAmount = amount - activeAmount;
    
    document.getElementById('activeLiquidity').textContent = '$' + Math.floor(activeAmount).toLocaleString();
    document.getElementById('activePercent').textContent = 
        ((activeAmount / amount) * 100).toFixed(1) + '% activated';
    
    document.getElementById('bufferedLiquidity').textContent = '$' + Math.floor(bufferedAmount).toLocaleString();
    document.getElementById('bufferedPercent').textContent = 
        ((bufferedAmount / amount) * 100).toFixed(1) + '% pending';
    
    let phaseText = '⏸ Intent Registered';
    let phaseColor = '#00d4aa';
    
    if (currentBlock > 0 && currentBlock <= delay) {
        phaseText = `⏱️ Delay Period (${currentBlock}/${delay})`;
        phaseColor = '#ffa502';
    } else if (currentBlock > delay && currentBlock <= delay + steps) {
        phaseText = `📊 Smoothing (${currentBlock - delay}/${steps})`;
        phaseColor = '#00d4aa';
    } else if (currentBlock > delay + steps) {
        phaseText = '✓ Fully Activated';
        phaseColor = '#00d4aa';
    }
    
    const phaseStatus = document.getElementById('phaseStatus');
    phaseStatus.textContent = phaseText;
    phaseStatus.style.color = phaseColor;
}

function resetSimulation() {
    if (demoConfig.interval) {
        clearInterval(demoConfig.interval);
    }
    
    demoConfig.isSimulating = false;
    demoConfig.currentBlock = 0;
    
    document.querySelectorAll('.action-type-btn, .range-slider').forEach(el => {
        el.disabled = false;
    });
    
    const runBtn = document.getElementById('runBtn');
    runBtn.disabled = false;
    runBtn.textContent = 'Run Simulation';
    
    document.getElementById('currentBlock').textContent = '0';
    document.getElementById('progressBar').style.width = '0%';
    document.getElementById('activeLiquidity').textContent = '$0';
    document.getElementById('activePercent').textContent = '0% activated';
    document.getElementById('bufferedLiquidity').textContent = '$' + demoConfig.amount.toLocaleString();
    document.getElementById('bufferedPercent').textContent = '100% pending';
    document.getElementById('phaseStatus').textContent = '⏸ Intent Registered';
    document.getElementById('phaseStatus').style.color = '#00d4aa';
}

function scrollToSection(sectionId) {
    const section = document.getElementById(sectionId);
    if (section) {
        section.scrollIntoView({ 
            behavior: 'smooth',
            block: 'start'
        });
    }
}

if (typeof window.ethereum !== 'undefined') {
    window.ethereum.on('accountsChanged', (accounts) => {
        if (accounts.length === 0) {
            // User disconnected wallet
            walletConnected = false;
            const btn = document.getElementById('walletBtn');
            const btnText = document.getElementById('walletText');
            btn.classList.remove('connected');
            btnText.textContent = 'Connect Wallet';
            showNotification('Wallet disconnected', 'info');
        } else {
            const address = accounts[0];
            const shortAddress = address.slice(0, 6) + '...' + address.slice(-4);
            document.getElementById('walletText').textContent = shortAddress;
            showNotification('Account changed', 'info');
        }
    });

    window.ethereum.on('chainChanged', (chainId) => {
        // Reload page on network change
        window.location.reload();
    });
}
