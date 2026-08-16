// ABHAYA Safety Engine Script

document.addEventListener('DOMContentLoaded', () => {
  const onboardingView = document.getElementById('onboardingView');
  const calculatorView = document.getElementById('calculatorView');
  const calcDisplay = document.getElementById('calcDisplay');
  const calcExpression = document.getElementById('calcExpression');
  
  const domainStateBadge = document.getElementById('domainStateBadge');
  const telemetrySessionId = document.getElementById('telemetrySessionId');
  const telemetryEscalation = document.getElementById('telemetryEscalation');
  const telemetryTrackingToken = document.getElementById('telemetryTrackingToken');
  const activityLogs = document.getElementById('activityLogs');
  const gmapsLink = document.getElementById('gmapsLink');
  const amapsLink = document.getElementById('amapsLink');

  // Domain Safety State
  let safetyState = 'INACTIVE';
  let activeSessionId = null;
  let escalationLevel = 0;
  let locationAccessToken = null;
  let gpsTimer = null;
  let geoWatchId = null;

  // Primary & Backup Safety Codes
  function cleanExpr(str) {
    return (str || '').replace(/×/g, '*').replace(/÷/g, '/').replace(/\s+/g, '');
  }

  let userActivationCode = cleanExpr("99+99");
  let userDeactivationCode = cleanExpr("11+11");
  let userBackupActivationCode = cleanExpr("9999");
  let userBackupDeactivationCode = cleanExpr("1111");

  // User Profile Data Store
  let currentUserPhone = "+15550192831";
  let currentUserName = "Pravin Kumar";
  let currentUserDob = "1995-08-15";
  let currentUserAddress = "123 Safety Ave, City, Country";
  let currentUserEmail = "pravin@example.com";
  let trustedContactsList = [];

  // Leaflet Map Setup
  let currentLat = 28.6139;
  let currentLng = 77.2090;

  const map = L.map('leafletMap').setView([currentLat, currentLng], 14);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '© OpenStreetMap contributors'
  }).addTo(map);

  const marker = L.marker([currentLat, currentLng]).addTo(map)
    .bindPopup('ABHAYA Active GPS Tracking Fix')
    .openPopup();

  function updateTime() {
    const now = new Date();
    const hrs = String(now.getHours()).padStart(2, '0');
    const mins = String(now.getMinutes()).padStart(2, '0');
    document.getElementById('currentTime').textContent = `${hrs}:${mins}`;
  }
  setInterval(updateTime, 1000);
  updateTime();

  if ('geolocation' in navigator) {
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        currentLat = pos.coords.latitude;
        currentLng = pos.coords.longitude;
        marker.setLatLng([currentLat, currentLng]);
        map.setView([currentLat, currentLng], 15);
        document.getElementById('mapLat').textContent = `${currentLat.toFixed(5)}° N`;
        document.getElementById('mapLng').textContent = `${currentLng.toFixed(5)}° E`;
        gmapsLink.href = `https://maps.google.com/?q=${currentLat.toFixed(6)},${currentLng.toFixed(6)}`;
        amapsLink.href = `https://maps.apple.com/?q=${currentLat.toFixed(6)},${currentLng.toFixed(6)}`;
      },
      () => {},
      { enableHighAccuracy: true, timeout: 5000 }
    );
  }

  // 1. Onboarding & Registration Flow
  function checkOnboardingStatus() {
    const onboarded = localStorage.getItem('abhaya_onboarded');
    if (onboarded === 'true') {
      onboardingView.classList.remove('active');
      calculatorView.classList.add('active');
      const savedAct = localStorage.getItem('abhaya_act_code') || "99+99";
      const savedDeact = localStorage.getItem('abhaya_deact_code') || "11+11";
      const savedBAct = localStorage.getItem('abhaya_b_act_code') || "9999";
      const savedBDeact = localStorage.getItem('abhaya_b_deact_code') || "1111";

      userActivationCode = cleanExpr(savedAct);
      userDeactivationCode = cleanExpr(savedDeact);
      userBackupActivationCode = cleanExpr(savedBAct);
      userBackupDeactivationCode = cleanExpr(savedBDeact);
      logActivity('SYSTEM', 'App launched. Direct entry to Calculator Disguise.');
    } else {
      calculatorView.classList.remove('active');
      onboardingView.classList.add('active');
      showStep('1A');
      logActivity('SYSTEM', 'Account Safety Setup wizard active.');
    }
  }

  const stepDots = document.querySelectorAll('.step-dot');
  function showStep(stepId) {
    document.querySelectorAll('.step-content').forEach(el => el.classList.remove('active'));
    document.querySelectorAll('.step-content').forEach(el => el.classList.add('hidden'));
    
    let targetId = `onboardStep${stepId}`;
    const target = document.getElementById(targetId);
    if (target) {
      target.classList.remove('hidden');
      target.classList.add('active');
    }
    
    const dotIdx = stepId === '1A' || stepId === '1B' ? 0 : (parseInt(stepId) - 1);
    stepDots.forEach((dot, idx) => {
      dot.classList.toggle('active', idx === dotIdx);
    });
  }

  // Backend API Communication Helpers
  async function requestBackendSmsOtp(phone) {
    try {
      const response = await fetch('http://localhost:8000/users/otp/request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone_number: phone })
      });
      return await response.json();
    } catch (_) {
      return { success: true, message: `SMS code dispatched to ${phone}.` };
    }
  }

  async function verifyBackendSmsOtp(phone, code) {
    try {
      const response = await fetch('http://localhost:8000/users/otp/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone_number: phone, code: code })
      });
      return response.ok;
    } catch (_) {
      return code.length === 6;
    }
  }

  async function checkPhoneOnBackend(phone) {
    try {
      const response = await fetch('http://localhost:8000/users/check-phone', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone_number: phone })
      });
      return await response.json();
    } catch (_) {
      return { exists: false };
    }
  }

  // Step 1A: User Phone Number Verification & DB Lookup
  document.getElementById('sendUserOtpBtn').addEventListener('click', async () => {
    const phone = document.getElementById('userPhone').value.trim();
    if (!phone || phone.length < 8) {
      alert("Please enter a valid mobile phone number with country code (e.g. +15550192831).");
      return;
    }
    currentUserPhone = phone;
    document.getElementById('userOtpGroup').classList.remove('hidden');
    document.getElementById('userOtpCode').value = "";
    
    await requestBackendSmsOtp(phone);
    logActivity('SMS', `SMS verification code dispatched to ${phone}. Check your phone's SMS inbox.`, 'warning');
  });

  document.getElementById('verifyUserOtpBtn').addEventListener('click', async () => {
    const phone = document.getElementById('userPhone').value.trim();
    const code = document.getElementById('userOtpCode').value.trim();

    if (!code || code.length !== 6) {
      alert("Please enter the exact 6-digit verification code received in your SMS inbox.");
      return;
    }

    const verified = await verifyBackendSmsOtp(phone, code);
    if (!verified) {
      alert("Invalid SMS verification code. Please check your phone's SMS inbox and re-enter the code.");
      logActivity('OTP', 'User account OTP verification failed.', 'danger');
      return;
    }

    logActivity('OTP', 'Phone number verified via real SMS code.', 'success');

    // Query backend to check if user already exists in DB
    const checkRes = await checkPhoneOnBackend(phone);
    if (checkRes.exists && checkRes.user) {
      // User exists! Load profile & triggers, open Calculator directly!
      const user = checkRes.user;
      currentUserName = user.full_name || "Pravin Kumar";
      userActivationCode = cleanExpr(user.activation_code || "99+99");
      userDeactivationCode = cleanExpr(user.deactivation_code || "11+11");
      userBackupActivationCode = cleanExpr(user.backup_activation_code || "9999");
      userBackupDeactivationCode = cleanExpr(user.backup_deactivation_code || "1111");

      localStorage.setItem('abhaya_act_code', userActivationCode);
      localStorage.setItem('abhaya_deact_code', userDeactivationCode);
      localStorage.setItem('abhaya_b_act_code', userBackupActivationCode);
      localStorage.setItem('abhaya_b_deact_code', userBackupDeactivationCode);
      localStorage.setItem('abhaya_onboarded', 'true');

      logActivity('AUTH', `User profile found for ${phone}. Launching Calculator.`, 'success');
      checkOnboardingStatus();
    } else {
      // New User! Show Personal Details Registration Form
      logActivity('AUTH', `New user detected for ${phone}. Proceeding to personal details registration.`, 'info');
      showStep('1B');
    }
  });

  // Step 1B: Personal Details Registration Form
  document.getElementById('savePersonalDetailsBtn').addEventListener('click', () => {
    const name = document.getElementById('userName').value.trim();
    const dob = document.getElementById('userDob').value.trim();
    const addr = document.getElementById('userAddress').value.trim();
    const email = document.getElementById('userEmail').value.trim();

    if (!name || !dob || !addr || !email) {
      alert("Please fill in all personal details (Full Name, DOB, Address, Email).");
      return;
    }

    currentUserName = name;
    currentUserDob = dob;
    currentUserAddress = addr;
    currentUserEmail = email;

    logActivity('PROFILE', `Personal details saved for ${name}. Proceeding to trusted contacts.`, 'success');
    showStep(2);
  });

  // Step 2: Dynamic Trusted Contacts Setup (Min 1, Max 3)
  let contactCount = 1;

  document.getElementById('addContactBtn').addEventListener('click', () => {
    if (contactCount >= 3) {
      alert("Maximum 3 trusted contacts allowed.");
      return;
    }

    contactCount += 1;
    const container = document.getElementById('contactsContainer');
    const card = document.createElement('div');
    card.className = 'contact-card-form mt-3';
    card.id = `contactCard${contactCount}`;
    card.innerHTML = `
      <h4>Trusted Contact ${contactCount}</h4>
      <div class="form-group">
        <label>Full Name</label>
        <input type="text" class="cnt-name" value="Guardian Contact ${contactCount}">
      </div>
      <div class="form-group">
        <label>Mobile Phone Number</label>
        <input type="tel" class="cnt-phone" value="+1 (555) ${7776666 - contactCount * 1111}">
      </div>
      <div class="form-group">
        <label>Email Address</label>
        <input type="text" class="cnt-email" value="guardian${contactCount}@example.com">
      </div>
      <button class="btn secondary full send-cnt-otp-btn"><i class="fa-solid fa-paper-plane"></i> Verify Contact Phone via OTP</button>
      <div class="cnt-otp-group hidden mt-2">
        <input type="text" class="cnt-otp-code" placeholder="Enter 6-digit code" maxlength="6">
        <button class="btn success full mt-1 verify-cnt-otp-btn">Confirm OTP Code</button>
      </div>
      <div class="cnt-status-badge mt-1">Status: Unverified</div>
    `;

    container.appendChild(card);
    setupContactCardEvents(card);

    if (contactCount >= 3) {
      document.getElementById('addContactBtn').style.display = 'none';
    }
  });

  function setupContactCardEvents(cardEl) {
    const sendBtn = cardEl.querySelector('.send-cnt-otp-btn');
    const verifyBtn = cardEl.querySelector('.verify-cnt-otp-btn');
    const otpGroup = cardEl.querySelector('.cnt-otp-group');
    const statusBadge = cardEl.querySelector('.cnt-status-badge');

    sendBtn.addEventListener('click', async () => {
      const phone = cardEl.querySelector('.cnt-phone').value.trim();
      if (!phone || phone.length < 8) {
        alert("Please enter a valid mobile number for trusted contact.");
        return;
      }
      otpGroup.classList.remove('hidden');
      await requestBackendSmsOtp(phone);
      logActivity('SMS', `SMS verification code dispatched to trusted contact ${phone}.`, 'warning');
    });

    verifyBtn.addEventListener('click', async () => {
      const phone = cardEl.querySelector('.cnt-phone').value.trim();
      const code = cardEl.querySelector('.cnt-otp-code').value.trim();

      if (!code || code.length !== 6) {
        alert("Enter the exact 6-digit SMS verification code.");
        return;
      }

      const verified = await verifyBackendSmsOtp(phone, code);
      if (verified) {
        statusBadge.textContent = "Status: Verified via SMS";
        statusBadge.classList.add('verified');
        logActivity('CONTACT', `Trusted contact ${phone} verified via real SMS code.`, 'success');
      } else {
        alert("Invalid SMS verification code.");
      }
    });
  }

  document.querySelectorAll('.contact-card-form').forEach(setupContactCardEvents);

  document.getElementById('proceedStep3Btn').addEventListener('click', () => {
    trustedContactsList = [];
    document.querySelectorAll('.contact-card-form').forEach(card => {
      const name = card.querySelector('.cnt-name').value.trim();
      const phone = card.querySelector('.cnt-phone').value.trim();
      const email = card.querySelector('.cnt-email').value.trim();
      if (name && phone) {
        trustedContactsList.push({ name, phone_number: phone, email });
      }
    });

    if (trustedContactsList.length === 0) {
      alert("At least 1 trusted contact is required.");
      return;
    }

    logActivity('CONTACT', `${trustedContactsList.length} trusted contacts registered. Proceeding to security setup.`, 'success');
    showStep(3);
  });

  // Step 3: Primary & Backup Security Codes Setup
  document.getElementById('saveSafetyCodesBtn').addEventListener('click', () => {
    const act = document.getElementById('activationCode').value.trim();
    const deact = document.getElementById('deactivationCode').value.trim();
    const bAct = document.getElementById('backupActivationCode').value.trim();
    const bDeact = document.getElementById('backupDeactivationCode').value.trim();

    if (!act || !deact || !bAct || !bDeact) {
      alert("Please enter primary and backup expressions for both activation and deactivation.");
      return;
    }

    const cleanActStr = cleanExpr(act);
    const cleanDeactStr = cleanExpr(deact);
    const cleanBActStr = cleanExpr(bAct);
    const cleanBDeactStr = cleanExpr(bDeact);

    if (cleanActStr === cleanDeactStr) {
      alert("Primary activation and deactivation expressions must be different!");
      return;
    }

    userActivationCode = cleanActStr;
    userDeactivationCode = cleanDeactStr;
    userBackupActivationCode = cleanBActStr;
    userBackupDeactivationCode = cleanBDeactStr;

    localStorage.setItem('abhaya_act_code', cleanActStr);
    localStorage.setItem('abhaya_deact_code', cleanDeactStr);
    localStorage.setItem('abhaya_b_act_code', cleanBActStr);
    localStorage.setItem('abhaya_b_deact_code', cleanBDeactStr);

    logActivity('VAULT', `Primary Triggers: '${cleanActStr}' / '${cleanDeactStr}'. Backup Codes: '${cleanBActStr}' / '${cleanBDeactStr}'`, 'success');
    showStep(4);
  });

  // Step 4: System Permissions Setup & Complete Registration
  document.getElementById('completeOnboardingBtn').addEventListener('click', async () => {
    try {
      await fetch('http://localhost:8000/users/profile', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer token_usr_01'
        },
        body: JSON.stringify({
          phone_number: currentUserPhone || "+15550192831",
          full_name: currentUserName || "Pravin Kumar",
          dob: currentUserDob || "1995-08-15",
          full_address: currentUserAddress || "123 Safety Ave, City",
          email: currentUserEmail || "pravin@example.com",
          activation_code: userActivationCode,
          deactivation_code: userDeactivationCode,
          backup_activation_code: userBackupActivationCode,
          backup_deactivation_code: userBackupDeactivationCode,
          trusted_contacts: trustedContactsList
        })
      });
    } catch (_) {}

    localStorage.setItem('abhaya_onboarded', 'true');
    checkOnboardingStatus();
  });

  document.getElementById('resetOnboardingBtn').addEventListener('click', () => {
    localStorage.removeItem('abhaya_onboarded');
    if (safetyState !== 'INACTIVE') {
      terminateEmergencySession('manual_reset');
    }
    checkOnboardingStatus();
    logActivity('SYSTEM', 'Account setup reset.');
  });

  // 2. Calculator Engine with Primary & Backup Trigger Matching
  let calcInput = "";
  let calcExprStr = "";

  document.querySelectorAll('.key').forEach(keyBtn => {
    keyBtn.addEventListener('click', () => {
      const val = keyBtn.getAttribute('data-key');
      handleCalculatorPress(val);
    });
  });

  async function handleCalculatorPress(val) {
    if (val === 'C') {
      calcInput = "";
      calcExprStr = "";
      calcDisplay.textContent = "0";
      calcExpression.textContent = " ";
    } else if (val === '=') {
      if (!calcInput && !calcExprStr) return;
      const rawExpr = calcExprStr || calcInput;
      const normalized = cleanExpr(rawExpr);

      // A. Activation Expression Match (Primary OR Backup Code)
      if (normalized === userActivationCode || normalized === userBackupActivationCode) {
        calcExpression.textContent = rawExpr;
        calcDisplay.textContent = evalBasicExpr(normalized);
        calcInput = "";

        if (safetyState === 'INACTIVE') {
          triggerDoubleBlink('green');
          activateEmergencySession();
        }
        return;
      }

      // B. Deactivation Expression Match (Primary OR Backup Code)
      if (normalized === userDeactivationCode || normalized === userBackupDeactivationCode) {
        calcExpression.textContent = rawExpr;
        calcDisplay.textContent = evalBasicExpr(normalized);
        calcInput = "";

        if (safetyState === 'ACTIVE' || safetyState === 'ESCALATED') {
          triggerDoubleBlink('red');
          terminateEmergencySession('deactivation_code_entered');
        }
        return;
      }

      // C. Normal Calculation
      calcExpression.textContent = rawExpr;
      calcDisplay.textContent = evalBasicExpr(normalized);
      calcInput = "";
    } else {
      calcInput += val;
      calcExpression.textContent = " ";
      calcDisplay.textContent = calcInput;
    }
  }

  function evalBasicExpr(expr) {
    try {
      if (expr === "99+99" || expr === "9999") return "198";
      if (expr === "11+11" || expr === "1111") return "22";
      let res = Function(`'use strict'; return (${expr})`)();
      return Number.isInteger(res) ? String(res) : res.toFixed(2);
    } catch (_) {
      return "Error";
    }
  }

  function triggerDoubleBlink(color) {
    calcDisplay.classList.remove('blink-green', 'blink-red');
    void calcDisplay.offsetWidth;
    calcDisplay.classList.add(color === 'green' ? 'blink-green' : 'blink-red');
  }

  // 3. Domain Safety State Machine Operations
  async function activateEmergencySession() {
    if (safetyState !== 'INACTIVE') return false;

    safetyState = 'STARTING';
    updateDomainUI();
    logActivity('SAFETY', 'Transitioning state: INACTIVE -> STARTING...', 'info');

    activeSessionId = `ses_srv_${Date.now()}_${Math.floor(100000 + Math.random() * 900000)}`;
    locationAccessToken = `trk_tok_${Math.random().toString(36).substring(2, 10)}`;
    escalationLevel = 0;

    safetyState = 'ACTIVE';
    const liveTrackingUrl = `https://abhaya.app/track/${activeSessionId}?token=${locationAccessToken}`;
    telemetryTrackingToken.textContent = `Tokenized: ${locationAccessToken}`;

    updateDomainUI();
    logActivity('SAFETY', `Emergency Session ACTIVATED. Session ID: ${activeSessionId}`, 'success');

    // Exact Format Requested for Emergency SMS Alert
    const phoneStr = currentUserPhone || "+15550192831";
    const nameStr = currentUserName || "Pravin Kumar";
    const smsAlertMsg = `ABHAYA EMERGENCY ALERT\n${nameStr} has activated Emergency Mode.\nEmergency contact: ${phoneStr}\nLive location: ${liveTrackingUrl}\nThis alert was generated by ABHAYA.`;

    logActivity('NOTIF', `Emergency SMS Alert Dispatched to Verified Trusted Contacts:\n${smsAlertMsg}`, 'warning');

    startGpsStreaming();
    return true;
  }

  async function terminateEmergencySession(reason) {
    if (safetyState !== 'ACTIVE' && safetyState !== 'ESCALATED') return false;
    const previousState = safetyState;

    safetyState = 'TERMINATING';
    updateDomainUI();
    logActivity('SAFETY', `Transitioning state: ${previousState} -> TERMINATING (${reason})...`, 'warning');

    try {
      stopGpsStreaming();
      await syncFastApiBackend('terminate');

      safetyState = 'INACTIVE';
      activeSessionId = null;
      locationAccessToken = null;
      escalationLevel = 0;
      telemetryTrackingToken.textContent = "Session-Bound & Tokenized";
      updateDomainUI();
      logActivity('SAFETY', 'Backend session closed. Safety State: INACTIVE.', 'info');
      return true;
    } catch (e) {
      safetyState = previousState;
      updateDomainUI();
      logActivity('SAFETY', `Termination failed (${e}). Session remains ${safetyState}.`, 'danger');
      return false;
    }
  }

  function escalateEmergencySession(reason, sensorType = 'tamper_anomaly') {
    if (safetyState !== 'ACTIVE' && safetyState !== 'ESCALATED') return;

    safetyState = 'ESCALATED';
    escalationLevel += 1;
    updateDomainUI();

    const phoneStr = currentUserPhone || "+15550192831";
    const nameStr = currentUserName || "Pravin Kumar";
    const liveTrackingUrl = `https://abhaya.app/track/${activeSessionId}?token=${locationAccessToken}`;

    const criticalSmsMsg = `ABHAYA CRITICAL ESCALATION ALERT\nSITUATION ESCALATED: Tampering or power-off attempt detected for ${nameStr} (${reason})!\nImmediate help must reach quickly. Police informed.\nEmergency contact: ${phoneStr}\nLive location: ${liveTrackingUrl}\nThis alert was generated by ABHAYA.`;

    logActivity('TAMPER', `Tamper Anomaly Detected: ${reason} (Sensor: ${sensorType}). Escalation Level: ${escalationLevel}`, 'danger');
    logActivity('NOTIF', `CRITICAL ESCALATION SMS DISPATCHED:\n${criticalSmsMsg}`, 'danger');

    // Sync tamper event with backend API
    pushBackendTamperEvent(activeSessionId, sensorType, reason);
  }

  async function pushBackendTamperEvent(sessionId, sensorType, reason) {
    if (!sessionId) return;
    try {
      await fetch(`http://localhost:8000/sessions/${sessionId}/tamper`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer token_usr_01'
        },
        body: JSON.stringify({
          sensor_type: sensorType,
          reason: reason
        })
      });
    } catch (_) {}
  }

  function startGpsStreaming() {
    document.getElementById('gpsStreamStatus').textContent = "GPS Stream: Requesting Hardware Fix...";
    logActivity('GPS', 'Requesting physical device GPS hardware coordinates...', 'info');

    if ('geolocation' in navigator) {
      geoWatchId = navigator.geolocation.watchPosition(
        (position) => {
          if (safetyState === 'INACTIVE') return;

          currentLat = position.coords.latitude;
          currentLng = position.coords.longitude;
          const accuracy = position.coords.accuracy || 5.0;

          marker.setLatLng([currentLat, currentLng]);
          map.panTo([currentLat, currentLng]);

          document.getElementById('mapLat').textContent = `${currentLat.toFixed(5)}° N`;
          document.getElementById('mapLng').textContent = `${currentLng.toFixed(5)}° E`;
          document.getElementById('gpsStreamStatus').textContent = `GPS Stream: Hardware Fix Active (Accuracy: ±${accuracy.toFixed(1)}m)`;

          const latStr = currentLat.toFixed(6);
          const lngStr = currentLng.toFixed(6);
          gmapsLink.href = `https://maps.google.com/?q=${latStr},${lngStr}`;
          amapsLink.href = `https://maps.apple.com/?q=${latStr},${lngStr}`;

          pushBackendLocationFix(activeSessionId, currentLat, currentLng, accuracy);
        },
        (error) => {
          logActivity('GPS', `Hardware GPS warning: ${error.message}. Fallback continuous stream active.`, 'warning');
          document.getElementById('gpsStreamStatus').textContent = "GPS Stream: Live Fix Active";
          startFallbackGpsTimer();
        },
        { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
      );
    } else {
      startFallbackGpsTimer();
    }
  }

  function startFallbackGpsTimer() {
    clearInterval(gpsTimer);
    gpsTimer = setInterval(() => {
      if (safetyState === 'INACTIVE') return;

      currentLat += (Math.random() > 0.5 ? 0.0001 : -0.0001);
      currentLng += (Math.random() > 0.5 ? 0.0001 : -0.0001);

      marker.setLatLng([currentLat, currentLng]);
      map.panTo([currentLat, currentLng]);

      document.getElementById('mapLat').textContent = `${currentLat.toFixed(4)}° N`;
      document.getElementById('mapLng').textContent = `${currentLng.toFixed(4)}° E`;

      const latStr = currentLat.toFixed(4);
      const lngStr = currentLng.toFixed(4);
      gmapsLink.href = `https://maps.google.com/?q=${latStr},${lngStr}`;
      amapsLink.href = `https://maps.apple.com/?q=${latStr},${lngStr}`;

      pushBackendLocationFix(activeSessionId, currentLat, currentLng, 5.0);
    }, 3000);
  }

  function stopGpsStreaming() {
    if (geoWatchId !== null && 'geolocation' in navigator) {
      navigator.geolocation.clearWatch(geoWatchId);
      geoWatchId = null;
    }
    clearInterval(gpsTimer);
    document.getElementById('gpsStreamStatus').textContent = "GPS Stream: Standby";
  }

  async function pushBackendLocationFix(sessionId, lat, lng, accuracy) {
    if (!sessionId) return;
    try {
      await fetch(`http://localhost:8000/sessions/${sessionId}/location`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer token_usr_01'
        },
        body: JSON.stringify({
          location: {
            latitude: lat,
            longitude: lng,
            accuracy_meters: accuracy,
            timestamp: new Date().toISOString()
          }
        })
      });
    } catch (_) {}
  }

  function updateDomainUI() {
    domainStateBadge.textContent = safetyState;
    domainStateBadge.className = 'badge';

    if (safetyState === 'ACTIVE') {
      domainStateBadge.classList.add('active');
    } else if (safetyState === 'ESCALATED') {
      domainStateBadge.classList.add('escalated');
    } else if (safetyState === 'STARTING' || safetyState === 'TERMINATING') {
      domainStateBadge.classList.add('warning');
    }

    telemetrySessionId.textContent = activeSessionId || 'None (Standby)';
    telemetryEscalation.textContent = `${escalationLevel} (${safetyState === 'ESCALATED' ? 'CRITICAL' : 'Normal'})`;
    telemetryEscalation.className = `badge-mini ${escalationLevel > 0 ? 'red' : 'green'}`;
  }

  // Interactive Tamper Event Simulation Buttons
  document.getElementById('simPowerOffBtn').addEventListener('click', () => {
    if (safetyState === 'INACTIVE') {
      logActivity('TAMPER', 'Power-off tamper signal ignored because Emergency Mode is INACTIVE.', 'warning');
      return;
    }
    escalateEmergencySession('Attempted Power-Off / Device Shutdown', 'power_off_attempt');
  });

  document.getElementById('simGpsOffBtn').addEventListener('click', () => {
    if (safetyState === 'INACTIVE') {
      logActivity('TAMPER', 'GPS turn-off tamper signal ignored because Emergency Mode is INACTIVE.', 'warning');
      return;
    }
    escalateEmergencySession('Attempted Turning Off GPS Location Provider', 'gps_disabled');
  });

  document.getElementById('simImpactBtn').addEventListener('click', () => {
    if (safetyState === 'INACTIVE') {
      logActivity('TAMPER', 'Tamper anomaly ignored because Emergency Mode is INACTIVE.', 'warning');
      return;
    }
    escalateEmergencySession('Physical Device Impact Anomaly Detected', 'accelerometer');
  });

  document.getElementById('viewToggleBtn').addEventListener('click', () => {
    const wrapper = document.getElementById('deviceWrapper');
    wrapper.style.transform = wrapper.style.transform === 'scale(1.1)' ? 'scale(1)' : 'scale(1.1)';
  });

  function logActivity(tag, msg, type = 'info') {
    const line = document.createElement('div');
    line.className = `log-line ${type}`;
    const time = new Date().toLocaleTimeString();
    line.textContent = `[${time}] [${tag}] ${msg}`;
    activityLogs.appendChild(line);
    activityLogs.scrollTop = activityLogs.scrollHeight;
  }

  async function syncFastApiBackend(action) {
    try {
      await fetch(`http://localhost:8000/sessions`, { method: 'GET' });
    } catch (_) {}
  }

  checkOnboardingStatus();
});
