/**

Simulador gas bidimensional model esferes dures.
A.Rosich, 2025

 */

// Histograma velocitats
int histEvery = 1;
int histK = 0;
int histBins = 18;
int[] hist = new int[histBins];
float histMaxSpeed = 1.0;
float fitSigma = 1.0;
float fitMeanV = 0.0;
float sigmaMin = 0.0;
float sigmaMax = 0.0;
boolean sigmaRangeInit = false;
boolean pistonOscOn = false;
float pistonOscFreq = 0.35;
float pistonOscAmp = 18.0;
float pistonOscTime = 0.0;
float pistonOscCenterW = 0.0;
float acousticDiss = 0.02;
float topWallDiss = 0.0;
float monitorRectW = 600.0;
float monitorRectH = 50.0;
float monitorRectX = 0.0;
float monitorRectY = 0.0;
boolean draggingMonitorRect = false;
float monitorDragDX = 0.0;
float monitorDragDY = 0.0;
float monitorDensity = 0.0;
int monitorCount = 0;
FloatList densityHistory = new FloatList();
FloatList pistonHistory = new FloatList();
boolean showDensityFFT = false;
float[] densityFFTMag = new float[0];
float densityFFTFMin = 0.0;
float densityFFTFMax = 0.0;
float densityFFTMinMag = 1e-12;
float densityFFTMaxMag = 1e-12;
int densityFFTLastFrame = -1000000;
int densityFFTUpdateEvery = 1000;
float densityFFTMinPlotFreq = 0.1;
int densityGraphWindow = 300;
 
 
 class Ball 
 {
  PVector position;
  PVector velocity;

  float radius, m, Ue ;

  Ball(float x, float y, float r_, float Ue) {
    position = new PVector(x, y);
    velocity = PVector.random2D();
    velocity.mult(Ue);
    radius = r_;
    m = 1.0;  
  }

  void update() {
    position.add(velocity);
  }


  void checkBoundaryCollision(int h, int w)
    {
    float eFixed = pistonOscOn ? constrain(1.0 - acousticDiss, 0.0, 1.0) : 1.0;
    float eTop = constrain(1.0 - topWallDiss, 0.0, 1.0);
    if (position.x > w-radius) {
      position.x = w-radius;
      velocity.x *= -eFixed;
    } else if (position.x < radius) {
      position.x = radius;
      velocity.x *= -eFixed;
    } else if (position.y > h-radius) {
      position.y = h-radius;
      float vyBefore = velocity.y;
      if (adiabaticMode || pistonOscOn) {
        // Paret mòbil: reflexió en el referencial del pistó.
        velocity.y = 2.0 * pistonVY - velocity.y;
      } else {
        velocity.y *= -1;
      }
      counter += (velocity.y - vyBefore);
    } else if (position.y < radius) {
      position.y = radius;
      velocity.y *= -eTop;
    }
  }

  void checkCollision(Ball other) {
    float dx = other.position.x - position.x;
    float dy = other.position.y - position.y;
    float minDistance = radius + other.radius;
    float distSq = dx * dx + dy * dy;
    float minDistSq = minDistance * minDistance;
    if (distSq >= minDistSq) return;

    float invMassA = 1.0 / m;
    float invMassB = 1.0 / other.m;

    float rvx = other.velocity.x - velocity.x;
    float rvy = other.velocity.y - velocity.y;
    float dist = sqrt(max(distSq, 0.000001));
    float nx;
    float ny;
    if (distSq < 0.000001) {
      // Cas degenerat: centres gairebé coincidents.
      float rvMag = sqrt(rvx * rvx + rvy * rvy);
      if (rvMag > 0.000001) {
        nx = rvx / rvMag;
        ny = rvy / rvMag;
      } else {
        nx = 1.0;
        ny = 0.0;
      }
      dist = minDistance;
    } else {
      nx = dx / dist;
      ny = dy / dist;
    }

    // Correcció de penetració suau (evita desviacions brusques).
    float overlap = minDistance - dist;
    float slop = 0.01;
    float percent = 0.8;
    float corrMag = max(overlap - slop, 0.0) * percent / (invMassA + invMassB);
    position.x -= nx * corrMag * invMassA;
    position.y -= ny * corrMag * invMassA;
    other.position.x += nx * corrMag * invMassB;
    other.position.y += ny * corrMag * invMassB;

    // Impuls només si s'estan acostant en la normal del xoc.
    float relNormal = rvx * nx + rvy * ny;
    if (relNormal > 0) return;

    float e = 1.0; // xoc elàstic
    float j = -(1.0 + e) * relNormal / (invMassA + invMassB);
    float ix = j * nx;
    float iy = j * ny;

    velocity.x -= ix * invMassA;
    velocity.y -= iy * invMassA;
    other.velocity.x += ix * invMassB;
    other.velocity.y += iy * invMassB;
  }

  void display() {
    noStroke();
    fill(255);
    ellipse(position.x, position.y, radius*2, radius*2);
  }
}
 

void draw() 
  {
  // Resposta en temps real dels controls d'oscil·lació del pistó.
  pistonOscFreq = waveFreqSlider.value;
  pistonOscAmp = waveAmpSlider.value;
  acousticDiss = wallDissSlider.value;
  topWallDiss = topWallDissSlider.value;
  adiabaticCompressStep = adiaSpeedSlider.value;

  if (!paused && !draggingPiston) {
    if (pistonOscOn) {
      float target = pistonOscCenterW + pistonOscAmp * sin(TWO_PI * pistonOscFreq * pistonOscTime);
      w = round(constrain(target, pistonMinW, pistonMaxW));
    } else if (adiabaticMode) {
      if (adiabaticDirection < 0) {
        w = round(max((float)pistonMinW, w - adiabaticCompressStep));
      } else if (adiabaticDirection > 0) {
        w = round(min((float)pistonMaxW, w + adiabaticCompressStep));
      }
    }
  }
  pistonVY = w - prevPistonW;
  prevPistonW = w;
  background(51);
  drawInsulatingWalls();
  
  if (!paused) {
    float dt = (frameRate > 1.0) ? (1.0 / frameRate) : (1.0 / 60.0);
    pistonOscTime += dt;
    for (Ball b : balls) {
      b.update();
      b.checkBoundaryCollision(w, h);
    }
    for (int i=0; i<balls.length-1; i = i+1){
      for (int j=i+1; j<balls.length; j = j+1){
        balls[j].checkCollision(balls[i]);
      }
    }
    k += 1;
    if (histEvery > 0) {
      histK += 1;
    }
    if (k == pressureEvery){
      float E = 0.0;
      for (int i=0; i<balls.length; i = i+1){
          E += 0.5*balls[i].m*(sq(balls[i].velocity.x) + sq(balls[i].velocity.y));
      }
      float pNow = -counter / max(1.0, (float)k);
      pressureDisplay = pNow;
      maxPressure = max(maxPressure * 0.995, pNow);
      if (maxPressure < 1) maxPressure = 1;
      if (!pressureRangeInit) {
        pressureMin = pNow;
        pressureMax = pNow;
        pressureRangeInit = true;
      } else {
        float decay = max(0.5, (pressureMax - pressureMin) * 0.02);
        pressureMin = min(pNow, pressureMin + decay);
        pressureMax = max(pNow, pressureMax - decay);
      }
      String line = pNow + " " + (w*h) + " " + (E/balls.length);
      println(line);
      logLines.append(line);
      k = 0;
      counter = 0.0;
    }
    if (histEvery > 0 && histK == histEvery) {
      updateHistogram();
      histK = 0;
    }
  }

  for (Ball b : balls) {
    b.display();
  }
  if (pistonOscOn) {
    updateDensityMonitor();
    drawDensityMonitor();
  }
  fill(70, 150, 255);
  rect(0, w, h, 20);
  drawPanel();
  
  }

  void keyPressed() {
    //histogram
    if (key == 'b' || key == 'B') {
      output = createWriter("vels.txt");
      for (int i=0; i<balls.length; i = i+1){
        velocity_list[i] = sqrt(sq(balls[i].velocity.x) + sq(balls[i].velocity.y));
        output.println(velocity_list[i]); // Write the coordinate to the file
      }
      output.flush(); // Writes the remaining data to the file
      output.close(); // Finishes the file
      //exit(); // Stops the program
    } else if  (key == 'v' || key == 'V') {
      output = createWriter("vels_2.txt");
      for (int i=0; i<balls.length; i = i+1){
        velocity_list[i] = sqrt(sq(balls[i].velocity.x) + sq(balls[i].velocity.y));
        output.println(velocity_list[i]); // Write the coordinate to the file
      }
      output.flush(); // Writes the remaining data to the file
      output.close(); // Finishes the file
    
    } else if  (key == 'x' || key == 'X') {
        exit(); 
    }
    if (!adiabaticMode && key == CODED) {
        if (keyCode == UP) {
          w = max(0, w - 25);
    }else if (keyCode == DOWN) {
          w = min(pistonMaxW, w + 25);
    }
         
    }
  }

  void mousePressed() {
    if (pistonOscOn && isInsideMonitorRect(mouseX, mouseY)) {
      draggingMonitorRect = true;
      monitorDragDX = mouseX - monitorRectX;
      monitorDragDY = mouseY - monitorRectY;
    } else if (!adiabaticMode && isInsidePiston(mouseX, mouseY)) {
      draggingPiston = true;
    } else if (isInside(resetX, resetY, buttonW, buttonH)) {
      resetSimulation();
    } else if (isInside(stopX, stopY, buttonW, buttonH)) {
      paused = !paused;
    } else if (isInside(saveX, saveY, buttonW, buttonH)) {
      saveThermo();
    } else if (isInside(shotX, shotY, buttonW, buttonH)) {
      takeScreenshot();
    } else if (!pistonOscOn && adiaSwitch.hit(mouseX, mouseY)) {
      boolean prevMode = adiaSwitch.lowMode;
      adiaSwitch.mousePressed(mouseX, mouseY);
      adiabaticMode = adiaSwitch.lowMode;
      if (adiabaticMode != prevMode) {
        // En entrar o sortir del mode adiabàtic, deixa el pistó en espera
        // fins que l'usuari premi una fletxa.
        adiabaticDirection = 0;
      }
    } else if (isInside(adiaUpX, adiaStepY, adiaStepW, adiaStepH)) {
      if (adiabaticMode) {
        adiabaticDirection = -1;
        adiaButtonHeld = true;
      }
    } else if (isInside(adiaDownX, adiaStepY, adiaStepW, adiaStepH)) {
      if (adiabaticMode) {
        adiabaticDirection = 1;
        adiaButtonHeld = true;
      }
    } else if (resSwitch.hit(mouseX, mouseY)) {
      boolean prev = resSwitch.lowMode;
      resSwitch.mousePressed(mouseX, mouseY);
      if (resSwitch.lowMode != prev) {
        lowRes = resSwitch.lowMode;
        savePixelDensityPreference(lowRes ? 1 : displayDensity());
        println("Canvi de pixelDensity guardat. Reiniciant sketch...");
        exit();
      }
    } else if (waveSwitch.hit(mouseX, mouseY)) {
      boolean wasPistonOscOn = pistonOscOn;
      waveSwitch.mousePressed(mouseX, mouseY);
      pistonOscOn = waveSwitch.lowMode;
      if (pistonOscOn) {
        if (!wasPistonOscOn) {
          // Preset ones acústiques
          countSlider.value = constrain(10, countSlider.minV, countSlider.maxV); // 2<<(10)=2048
          energySlider.value = constrain(2, energySlider.minV, energySlider.maxV); // 1<<(2)=4
          waveFreqSlider.value = constrain(0.661, waveFreqSlider.minV, waveFreqSlider.maxV);
          waveAmpSlider.value = constrain(72.0, waveAmpSlider.minV, waveAmpSlider.maxV);
          wallDissSlider.value = constrain(0.75, wallDissSlider.minV, wallDissSlider.maxV);
          w = constrain(750, pistonMinW, pistonMaxW);
          prevPistonW = w;
          applySliderChanges();
        }
        pistonOscCenterW = w;
        pistonOscTime = 0.0;
      }
    } else if (hitDensityPlotToggle()) {
      // handled
    } else if (hitDensityFFTRefreshButton()) {
      // handled
    } else if (hitHistButtons()) {
      // handled
    } else {
      countSlider.mousePressed(mouseX, mouseY);
      if (!adiabaticMode) {
        energySlider.mousePressed(mouseX, mouseY);
      }
      pressureSlider.mousePressed(mouseX, mouseY);
      if (adiabaticMode) {
        adiaSpeedSlider.mousePressed(mouseX, mouseY);
      }
      if (pistonOscOn) {
        waveFreqSlider.mousePressed(mouseX, mouseY);
        waveAmpSlider.mousePressed(mouseX, mouseY);
        wallDissSlider.mousePressed(mouseX, mouseY);
        topWallDissSlider.mousePressed(mouseX, mouseY);
      }
    }
  }

  void mouseDragged() {
    if (adiabaticMode && adiaButtonHeld) {
      if (isInside(adiaUpX, adiaStepY, adiaStepW, adiaStepH)) {
        adiabaticDirection = -1;
      } else if (isInside(adiaDownX, adiaStepY, adiaStepW, adiaStepH)) {
        adiabaticDirection = 1;
      } else {
        adiabaticDirection = 0;
      }
    }

    if (draggingMonitorRect) {
      float nx = mouseX - monitorDragDX;
      float ny = mouseY - monitorDragDY;
      monitorRectX = constrain(nx, 0, boardW - monitorRectW);
      monitorRectY = constrain(ny, 0, boardH - monitorRectH);
      return;
    }

    if (draggingPiston) {
      if (!adiabaticMode) {
        w = constrain(mouseY, 0, windowH - 20);
      }
      return;
    }
    countSlider.mouseDragged(mouseX, mouseY);
    if (!adiabaticMode) {
      energySlider.mouseDragged(mouseX, mouseY);
    }
    pressureSlider.mouseDragged(mouseX, mouseY);
    if (adiabaticMode) {
      adiaSpeedSlider.mouseDragged(mouseX, mouseY);
    }
    if (pistonOscOn) {
      waveFreqSlider.mouseDragged(mouseX, mouseY);
      waveAmpSlider.mouseDragged(mouseX, mouseY);
      wallDissSlider.mouseDragged(mouseX, mouseY);
      topWallDissSlider.mouseDragged(mouseX, mouseY);
    }
  }

  void mouseReleased() {
    draggingPiston = false;
    draggingMonitorRect = false;
    if (adiabaticMode) {
      adiaButtonHeld = false;
      adiabaticDirection = 0;
    }
    boolean wasDragging = countSlider.dragging || pressureSlider.dragging || (adiabaticMode && adiaSpeedSlider.dragging) || (!adiabaticMode && energySlider.dragging) || (pistonOscOn && (waveFreqSlider.dragging || waveAmpSlider.dragging || wallDissSlider.dragging || topWallDissSlider.dragging));
    countSlider.mouseReleased();
    if (!adiabaticMode) {
      energySlider.mouseReleased();
    } else {
      energySlider.dragging = false;
    }
    pressureSlider.mouseReleased();
    if (adiabaticMode) {
      adiaSpeedSlider.mouseReleased();
    } else {
      adiaSpeedSlider.dragging = false;
    }
    if (pistonOscOn) {
      waveFreqSlider.mouseReleased();
      waveAmpSlider.mouseReleased();
      wallDissSlider.mouseReleased();
      topWallDissSlider.mouseReleased();
    } else {
      waveFreqSlider.dragging = false;
      waveAmpSlider.dragging = false;
      wallDissSlider.dragging = false;
      topWallDissSlider.dragging = false;
    }
    if (wasDragging) {
      applySliderChanges();
    }
  }

  boolean isInside(float x, float y, float w_, float h_) {
    return mouseX >= x && mouseX <= x + w_ && mouseY >= y && mouseY <= y + h_;
  }

  boolean isInsidePiston(float mx, float my) {
    return (mx >= 0 && mx <= h && my >= w && my <= w + 20);
  }

  boolean isInsideMonitorRect(float mx, float my) {
    return (mx >= monitorRectX && mx <= monitorRectX + monitorRectW &&
            my >= monitorRectY && my <= monitorRectY + monitorRectH);
  }

  boolean hitHistButtons() {
    if (pistonOscOn) return false;
    float by = sliderY + sliderGap * 2 + 170 + 200 + 180;
    float bx = panelX + 40;
    float bw = 60;
    float bh = 24;
    float gap = 8;
    if (isInside(bx, by, bw, bh)) {
      histEvery = 0;
      histK = 0;
      return true;
    } else if (isInside(bx + (bw + gap), by, bw, bh)) {
      histEvery = 1;
      histK = 0;
      if (histEvery > 0) updateHistogram();
      return true;
    } else if (isInside(bx + (bw + gap) * 2, by, bw, bh)) {
      histEvery = 10;
      histK = 0;
      if (histEvery > 0) updateHistogram();
      return true;
    } else if (isInside(bx + (bw + gap) * 3, by, bw, bh)) {
      histEvery = 100;
      histK = 0;
      if (histEvery > 0) updateHistogram();
      return true;
    } else if (isInside(bx + (bw + gap) * 4, by, bw, bh)) {
      histEvery = 1000;
      histK = 0;
      if (histEvery > 0) updateHistogram();
      return true;
    }
    return false;
  }

  boolean hitDensityPlotToggle() {
    if (!pistonOscOn) return false;
    float hx = panelX + 60;
    float hy = sliderY + sliderGap * 2 + 170 + 200;
    float hh = 120;
    float bw = 190;
    float bh = 24;
    float by = hy + hh + 30;
    if (isInside(hx, by, bw, bh)) {
      showDensityFFT = !showDensityFFT;
      return true;
    }
    return false;
  }

  boolean hitDensityFFTRefreshButton() {
    if (!pistonOscOn || !showDensityFFT) return false;
    float hx = panelX + 60;
    float hy = sliderY + sliderGap * 2 + 170 + 200;
    float hh = 120;
    float bw = 150;
    float bh = 24;
    float by = hy + hh + 30;
    float bx = hx + 198;
    if (isInside(bx, by, bw, bh)) {
      updateDensityFFTCache();
      return true;
    }
    return false;
  }
  
  void drawPanel() {
    noStroke();
    fill(30);
    rect(panelX, 0, panelW, height);
    
    drawButtonIcon(resetX, resetY, "Reset", ICON_RESET);
    drawButtonIcon(stopX, stopY, paused ? "Resume" : "Stop", paused ? ICON_PLAY : ICON_PAUSE);
    drawButtonIcon(saveX, saveY, "Guardar", ICON_SAVE);
    drawButtonIcon(shotX, shotY, "Captura", ICON_SHOT);

    adiaSwitch.x = panelX + 30;
    adiaSwitch.y = resetY + buttonH + 10;
    adiaSwitch.draw();
    if (pistonOscOn) {
      noStroke();
      fill(30, 140);
      rect(adiaSwitch.x, adiaSwitch.y, adiaSwitch.w, adiaSwitch.h, adiaSwitch.h * 0.5);
      stroke(120);
      strokeWeight(1);
      noFill();
      rect(adiaSwitch.x, adiaSwitch.y, adiaSwitch.w, adiaSwitch.h, adiaSwitch.h * 0.5);
      noStroke();
    }
    adiabaticMode = adiaSwitch.lowMode;

    adiaStepY = adiaSwitch.y;
    adiaUpX = adiaSwitch.x + adiaSwitch.w + 10;
    adiaDownX = adiaUpX + adiaStepW + 8;
    drawMiniButtonState(adiaUpX, adiaStepY, adiaStepW, adiaStepH, "↑", adiabaticMode && adiabaticDirection < 0, adiabaticMode);
    drawMiniButtonState(adiaDownX, adiaStepY, adiaStepW, adiaStepH, "↓", adiabaticMode && adiabaticDirection > 0, adiabaticMode);
    adiaSpeedSlider.x = sliderX;
    adiaSpeedSlider.y = sliderY + sliderGap * 3;
    adiaSpeedSlider.w = sliderW;
    drawAdiaSpeedSlider();

    resSwitch.x = panelX + 30;
    resSwitch.y = resetY + buttonH + 54;
    resSwitch.draw();
    fill(220);
    textAlign(LEFT, CENTER);
    textSize(12);
    text("Resolució gràfics (cal reiniciar)", resSwitch.x + resSwitch.w + 10, resSwitch.y + resSwitch.h * 0.5);

    waveSwitch.x = panelX + 330;
    waveSwitch.y = resetY + buttonH + 10;
    waveSwitch.draw();
    pistonOscOn = waveSwitch.lowMode;
    fill(220);
    textAlign(LEFT, CENTER);
    textSize(12);
    text("Ones acústiques", waveSwitch.x + waveSwitch.w + 10, waveSwitch.y + waveSwitch.h * 0.5);

    waveFreqSlider.x = panelX + 330;
    waveFreqSlider.y = resetY + buttonH + 70;
    waveFreqSlider.w = panelW - 370;
    drawWaveFreqSlider();
    waveAmpSlider.x = panelX + 330;
    waveAmpSlider.y = resetY + buttonH + 114;
    waveAmpSlider.w = panelW - 370;
    if (pistonOscOn) {
      waveAmpSlider.drawNoLabel();
    } else {
      waveAmpSlider.drawNoLabelDisabled();
    }
    fill(pistonOscOn ? 220 : 170);
    textAlign(LEFT, BOTTOM);
    textSize(13);
    text("Amplitud [px]: " + nf(waveAmpSlider.value, 0, 1), waveAmpSlider.x, waveAmpSlider.y - 3);
    wallDissSlider.x = panelX + 330;
    wallDissSlider.y = resetY + buttonH + 158;
    wallDissSlider.w = panelW - 370;
    drawWallDissSlider();
    topWallDissSlider.x = panelX + 330;
    topWallDissSlider.y = resetY + buttonH + 202;
    topWallDissSlider.w = panelW - 370;
    drawTopWallDissSlider();
    if (pistonOscOn) {
      fill(220);
      textAlign(LEFT, TOP);
      textSize(13);
      float infoY = topWallDissSlider.y + 20;
      text("ρ (quadrat): " + String.format("%.2e", monitorDensity), panelX + 330, infoY);
      text("N dins = " + monitorCount + " / A = " + int(monitorRectW * monitorRectH), panelX + 330, infoY + 16);
    }

    fill(220);
    textAlign(LEFT, TOP);
    textSize(12);
    //text("Paràmetres", sliderX, sliderY - 24);
    drawCountSlider();
    drawEnergySlider();
    drawPressureSlider();

    drawGauges();
    if (pistonOscOn) {
      float hx = panelX + 60;
      float hy = sliderY + sliderGap * 2 + 170 + 200;
      float hw = panelW - 120;
      float hh = 120;
      fill(220);
      textAlign(LEFT, TOP);
      textSize(14);
      if (showDensityFFT) {
        text("Espectre FFT de ρ", hx, hy - 18);
        drawDensityFFT(hx, hy, hw, hh);
      } else {
        text("Gràfic de ρ", hx, hy - 18);
        drawDensityGraph(hx, hy, hw, hh);
      }
      drawMiniButtonIcon(hx, hy + hh + 30, 190, 24, showDensityFFT ? "Mostra ρ" : "Mostra FFT", false, ICON_PLAY);
      if (showDensityFFT) {
        drawMiniButtonIcon(hx + 198, hy + hh + 30, 150, 24, "Refresca FFT", false, ICON_RESET);
      }
    } else {
      if (histEvery > 0) {
        drawHistogram();
      }
      drawHistButtons();
    }
  }
  
  void drawButton(float x, float y, String label) {
    fill(200);
    rect(x, y, buttonW, buttonH, 6);
    fill(20);
    textAlign(CENTER, CENTER);
    textSize(13);
    text(label, x + buttonW/2.0, y + buttonH/2.0);
  }

  void drawButtonIcon(float x, float y, String label, int icon) {
    fill(200);
    rect(x, y, buttonW, buttonH, 6);
    float cy = y + buttonH/2.0;
    float iconGap = 8;
    float iconSize = 12;
    float textW = textWidth(label);
    float totalW = iconSize + iconGap + textW;
    float startX = x + (buttonW - totalW) * 0.5;
    float cx = startX + iconSize * 0.5;
    drawIcon(icon, cx, cy, 12);
    fill(20);
    textAlign(LEFT, CENTER);
    textSize(13);
    text(label, startX + iconSize + iconGap, cy);
  }

  void drawInsulatingWalls() {
    // Visualització de parets "aïllants" (reflectores)
    stroke(70, 150, 255);
    strokeWeight(3);
    noFill();
    rect(0, 0, h, w);

    // petit patró en ziga-zaga a la paret dreta
    float x = h;
    float step = 12;
    for (float y = 0; y < w; y += step) {
      line(x, y, x + 8, y + step/2.0);
    }
    strokeWeight(1);
  }

  void resetSimulation() {
    balls = new Ball[n_balls];
    velocity_list = new float[n_balls];
    for (int jk = 0; jk < n_balls; jk++){
      balls[jk] = new Ball(random(0,h), random(0,w), 2.0, energyMult);
    }
    counter = 0.0;
    k = 0;
    paused = false;
    pressureDisplay = 0.0;
    maxPressure = 10.0;
    maxVolume = 1000.0;
    histK = 0;
    if (histEvery > 0) updateHistogram();
    pressureRangeInit = false;
    pressureMin = 0.0;
    pressureMax = 0.0;
    sigmaRangeInit = false;
    sigmaMin = 0.0;
    sigmaMax = 0.0;
    pistonOscCenterW = w;
    pistonOscTime = 0.0;
    prevPistonW = w;
    pistonVY = 0.0;
    logLines.clear();
    densityHistory.clear();
    pistonHistory.clear();
    densityFFTMag = new float[0];
    densityFFTLastFrame = -1000000;
  }

  float computeEnergy() {
    float E = 0.0;
    for (int i=0; i<balls.length; i = i+1){
      E += 0.5*balls[i].m*(sq(balls[i].velocity.x) + sq(balls[i].velocity.y));
    }
    return E/balls.length;
  }

  void saveThermo() {
    PrintWriter out = createWriter("dades_termo.dat");
    for (int i = 0; i < logLines.size(); i++) {
      out.println(logLines.get(i));
    }
    out.flush();
    out.close();
  }

  void takeScreenshot() {
    saveFrame("captura-####.png");
  }

  void updateDensityMonitor() {
    float rw = monitorRectW;
    float rh = monitorRectH;
    monitorRectX = constrain(monitorRectX, 0, boardW - rw);
    monitorRectY = constrain(monitorRectY, 0, boardH - rh);
    float sx = monitorRectX;
    float sy = monitorRectY;
    monitorCount = 0;
    for (int i = 0; i < balls.length; i++) {
      float bx = balls[i].position.x;
      float by = balls[i].position.y;
      if (bx >= sx && bx <= sx + rw && by >= sy && by <= sy + rh) {
        monitorCount++;
      }
    }
    monitorDensity = monitorCount / max(1.0, rw * rh);
    densityHistory.append(monitorDensity);
    pistonHistory.append((float)w);
  }

  void drawDensityMonitor() {
    float rw = monitorRectW;
    float rh = monitorRectH;
    float sx = monitorRectX;
    float sy = monitorRectY;
    noFill();
    stroke(170);
    strokeWeight(2);
    rect(sx, sy, rw, rh);
    strokeWeight(1);
  }

  void drawDensityGraph(float gx, float gy, float gw, float gh) {
    noStroke();
    fill(30);
    rect(gx, gy, gw, gh, 6);

    stroke(120);
    strokeWeight(1);
    line(gx, gy + gh, gx + gw, gy + gh);
    line(gx, gy, gx, gy + gh);
    line(gx + gw, gy, gx + gw, gy + gh);

    int nAll = densityHistory.size();
    if (nAll < 2) return;
    int n = min(nAll, densityGraphWindow);
    int startIdx = nAll - n;

    float dMin = densityHistory.get(startIdx);
    float dMax = densityHistory.get(startIdx);
    for (int i = startIdx + 1; i < nAll; i++) {
      float d = densityHistory.get(i);
      if (d < dMin) dMin = d;
      if (d > dMax) dMax = d;
    }
    if (abs(dMax - dMin) < 1e-8) {
      dMax = dMin + 1e-8;
    }

    // Ticks i números eixos (lineal-lineal)
    int xTicks = 8;
    int yTicks = 8;
    int yLabelStride = 2;
    stroke(150);
    strokeWeight(1);
    fill(170);
    textSize(10);
    for (int i = 0; i <= xTicks; i++) {
      float t = i / float(xTicks);
      float xt = gx + t * gw;
      line(xt, gy + gh, xt, gy + gh + 4);
      int idx = startIdx + int(round(t * max(0, n - 1)));
      textAlign(CENTER, TOP);
      text(str(idx), xt, gy + gh + 6);
    }
    for (int i = 0; i <= yTicks; i++) {
      float t = i / float(yTicks);
      float yt = gy + gh - t * gh;
      line(gx - 4, yt, gx, yt);
      if (i % yLabelStride == 0) {
        float v = lerp(dMin, dMax, t);
        textAlign(RIGHT, CENTER);
        text(String.format("%.2e", v), gx - 6, yt);
      }
    }

    stroke(120, 190, 255);
    strokeWeight(0.7);
    noFill();
    beginShape();
    for (int i = 0; i < n; i++) {
      float x = gx + map(i, 0, max(1, n - 1), 0, gw);
      float y = gy + gh - map(densityHistory.get(startIdx + i), dMin, dMax, 0, gh - 4) - 2;
      vertex(x, y);
    }
    endShape();

    // Sèrie del pistó (MHS) sobre eix vertical dret
    if (pistonHistory.size() >= nAll) {
      float pMin = pistonHistory.get(startIdx);
      float pMax = pistonHistory.get(startIdx);
      for (int i = startIdx + 1; i < nAll; i++) {
        float p = pistonHistory.get(i);
        if (p < pMin) pMin = p;
        if (p > pMax) pMax = p;
      }
      if (abs(pMax - pMin) < 1e-6) pMax = pMin + 1.0;

      stroke(230, 170, 40);
      strokeWeight(0.7);
      noFill();
      beginShape();
      for (int i = 0; i < n; i++) {
        float x = gx + map(i, 0, max(1, n - 1), 0, gw);
        float y = gy + gh - map(pistonHistory.get(startIdx + i), pMin, pMax, 0, gh - 4) - 2;
        vertex(x, y);
      }
      endShape();

      stroke(170);
      strokeWeight(1);
      fill(170);
      textSize(10);
      for (int i = 0; i <= yTicks; i++) {
        float t = i / float(yTicks);
        float yt = gy + gh - t * gh;
        line(gx + gw, yt, gx + gw + 4, yt);
        if (i % yLabelStride == 0) {
          float pv = lerp(pMin, pMax, t);
          textAlign(LEFT, CENTER);
          text(nf(pv, 0, 1), gx + gw + 6, yt);
        }
      }
      textAlign(RIGHT, TOP);
      text("pistó(t)", gx + gw - 4, gy + 2);
    }

    fill(180);
    textAlign(LEFT, TOP);
    textSize(11);
    text("ρ(t)", gx + 4, gy + 4);
    textAlign(CENTER, TOP);
    text("frame", gx + gw * 0.5, gy + gh + 22);
    textAlign(RIGHT, TOP);
    text(String.format("%.2e", dMax), gx + gw - 4, gy + 4);
    textAlign(RIGHT, BOTTOM);
    text(String.format("%.2e", dMin), gx + gw - 4, gy + gh - 2);
  }

  void drawDensityFFT(float gx, float gy, float gw, float gh) {
    noStroke();
    fill(30);
    rect(gx, gy, gw, gh, 6);

    stroke(120);
    strokeWeight(1);
    line(gx, gy + gh, gx + gw, gy + gh);
    line(gx, gy, gx, gy + gh);

    if (densityFFTMag.length == 0 || frameCount - densityFFTLastFrame >= densityFFTUpdateEvery) {
      updateDensityFFTCache();
    }
    if (densityFFTMag.length < 2) return;

    int kMax = densityFFTMag.length - 1;
    float plotMinF = max(densityFFTMinPlotFreq, densityFFTFMin);
    int kStart = max(1, int(ceil(plotMinF / max(densityFFTFMin, 1e-6))));
    if (kStart >= kMax) return;

    float minMagPlot = 1e30;
    float maxMagPlot = 1e-30;
    for (int kf = kStart; kf <= kMax; kf++) {
      float m = max(densityFFTMag[kf], 1e-12);
      if (m < minMagPlot) minMagPlot = m;
      if (m > maxMagPlot) maxMagPlot = m;
    }

    float logFMin = log(max(plotMinF, 1e-6));
    float logFMax = log(max(densityFFTFMax, densityFFTFMin + 1e-6));
    float logMMin = log(max(minMagPlot, 1e-12));
    float logMMax = log(max(maxMagPlot, 1e-12));
    if (abs(logMMax - logMMin) < 1e-9) {
      logMMax = logMMin + 1.0;
    }

    // Ticks i números eixos (log-log, per dècades)
    stroke(150);
    strokeWeight(1);
    fill(170);
    textSize(10);
    int pFxMin = int(floor(log(plotMinF) / log(10.0)));
    int pFxMax = int(ceil(log(densityFFTFMax) / log(10.0)));
    float[] minorLog = {log(2.0), log(5.0)};
    // Ticks menors horitzontals (sense etiqueta)
    for (int p = pFxMin; p <= pFxMax; p++) {
      float decadeBase = p * log(10.0);
      for (int mi = 0; mi < minorLog.length; mi++) {
        float lf = decadeBase + minorLog[mi];
        float fTick = exp(lf);
        if (fTick < plotMinF || fTick > densityFFTFMax) continue;
        float xt = gx + map(lf, logFMin, logFMax, 0, gw);
        line(xt, gy + gh, xt, gy + gh + 2);
      }
    }
    for (int p = pFxMin; p <= pFxMax; p++) {
      float fTick = pow(10.0, p);
      if (fTick < plotMinF || fTick > densityFFTFMax) continue;
      float xt = gx + map(log(fTick), logFMin, logFMax, 0, gw);
      line(xt, gy + gh, xt, gy + gh + 4);
      textAlign(CENTER, TOP);
      text(String.format("%.0e", fTick), xt, gy + gh + 6);
    }
    // Més números a l'eix horitzontal: etiqueta també 2*10^p i 5*10^p
    for (int p = pFxMin; p <= pFxMax; p++) {
      float decadeBase = p * log(10.0);
      for (int mi = 0; mi < minorLog.length; mi++) {
        float lf = decadeBase + minorLog[mi];
        float fTick = exp(lf);
        if (fTick < plotMinF || fTick > densityFFTFMax) continue;
        float xt = gx + map(lf, logFMin, logFMax, 0, gw);
        textAlign(CENTER, TOP);
        text(String.format("%.0e", fTick), xt, gy + gh + 6);
      }
    }

    int pMyMin = int(floor(log(exp(logMMin)) / log(10.0)));
    int pMyMax = int(ceil(log(exp(logMMax)) / log(10.0)));
    // Ticks menors verticals (sense etiqueta)
    for (int p = pMyMin; p <= pMyMax; p++) {
      float decadeBase = p * log(10.0);
      for (int mi = 0; mi < minorLog.length; mi++) {
        float lm = decadeBase + minorLog[mi];
        float mTick = exp(lm);
        if (mTick < exp(logMMin) || mTick > exp(logMMax)) continue;
        float yt = gy + gh - map(lm, logMMin, logMMax, 0, gh);
        line(gx - 2, yt, gx, yt);
      }
    }
    // Almenys 4 valors etiquetats a l'eix vertical (espaiats en log)
    int yLabels = 4;
    for (int i = 0; i < yLabels; i++) {
      float t = (yLabels == 1) ? 0.0 : i / float(yLabels - 1);
      float lm = lerp(logMMin, logMMax, t);
      float mTick = exp(lm);
      float yt = gy + gh - map(lm, logMMin, logMMax, 0, gh);
      line(gx - 4, yt, gx, yt);
      textAlign(RIGHT, CENTER);
      text(String.format("%.1e", mTick), gx - 6, yt);
    }

    stroke(230, 170, 40);
    strokeWeight(1);
    noFill();
    int peakK = kStart;
    float peakMag = densityFFTMag[kStart];
    beginShape();
    for (int kf = kStart; kf <= kMax; kf++) {
      if (densityFFTMag[kf] > peakMag) {
        peakMag = densityFFTMag[kf];
        peakK = kf;
      }
      float f = kf * densityFFTFMin;
      float xPlot = gx + map(log(f), logFMin, logFMax, 0, gw);
      float yPlot = gy + gh - map(log(densityFFTMag[kf]), logMMin, logMMax, 0, gh - 4) - 2;
      vertex(xPlot, yPlot);
    }
    endShape();

    float peakF = peakK * densityFFTFMin;
    float peakX = gx + map(log(max(peakF, 1e-6)), logFMin, logFMax, 0, gw);
    float peakY = gy + gh - map(log(max(peakMag, 1e-12)), logMMin, logMMax, 0, gh - 4) - 2;
    noStroke();
    fill(120, 190, 255);
    ellipse(peakX, peakY, 5, 5);
    textAlign(LEFT, BOTTOM);
    textSize(11);
    text(nf(peakF, 0, 2) + " Hz", min(peakX + 6, gx + gw - 62), max(gy + 12, peakY - 4));

    float nyquist = densityFFTFMax;
    fill(180);
    textAlign(LEFT, BOTTOM);
    text(nf(plotMinF, 0, 2) + " Hz", gx + 4, gy + gh - 2);
    textAlign(RIGHT, BOTTOM);
    text(nf(nyquist, 0, 1) + " Hz", gx + gw - 4, gy + gh - 2);
    textAlign(RIGHT, TOP);
    text(nfc(maxMagPlot, 6), gx + gw - 4, gy + 4);
    textAlign(RIGHT, BOTTOM);
    text(nfc(minMagPlot, 6), gx + gw - 4, gy + gh - 16);
  }

  void updateDensityFFTCache() {
    int nAll = densityHistory.size();
    int n = min(nAll, 10000);
    if (n < 8) return;

    float[] x = new float[n];
    int start = nAll - n;
    float mean = 0.0;
    for (int i = 0; i < n; i++) {
      x[i] = densityHistory.get(start + i);
      mean += x[i];
    }
    mean /= n;
    for (int i = 0; i < n; i++) {
      x[i] -= mean;
    }

    float sampleRate = (frameRate > 1.0) ? frameRate : 60.0;
    int kMax = n / 2;
    if (kMax < 2) return;

    float[] magBase = new float[kMax + 1];
    float minMag = 1e30;
    float maxMag = 1e-30;
    for (int kf = 1; kf <= kMax; kf++) {
      float re = 0.0;
      float im = 0.0;
      for (int t = 0; t < n; t++) {
        float ang = TWO_PI * kf * t / n;
        re += x[t] * cos(ang);
        im -= x[t] * sin(ang);
      }
      float m = sqrt(re * re + im * im) / n;
      m = max(m, 1e-12);
      magBase[kf] = m;
      if (m < minMag) minMag = m;
      if (m > maxMag) maxMag = m;
    }

    int up = 150;
    int kDenseMax = kMax * up;
    float[] magDense = new float[kDenseMax + 1];
    for (int kd = 1; kd <= kDenseMax; kd++) {
      float kf = kd / float(up);
      int k0 = int(floor(kf));
      if (k0 < 1) k0 = 1;
      int k1 = min(k0 + 1, kMax);
      float frac = kf - k0;
      magDense[kd] = lerp(magBase[k0], magBase[k1], frac);
    }

    densityFFTMag = magDense;
    densityFFTFMin = (sampleRate / n) / up;
    densityFFTFMax = sampleRate * 0.5;
    densityFFTMinMag = max(minMag, 1e-12);
    densityFFTMaxMag = max(maxMag, 1e-12);
    densityFFTLastFrame = frameCount;
  }

  int loadPixelDensityPreference() {
    try {
      String path = sketchPath(".pixel_density_pref.txt");
      String[] lines = loadStrings(path);
      if (lines != null && lines.length > 0) {
        int pd = parseInt(trim(lines[0]));
        if (pd >= 1) return pd;
      }
    } catch (Exception e) {
      // Si falla, usem la densitat per defecte de la pantalla
    }
    return displayDensity();
  }

  void savePixelDensityPreference(int pd) {
    String path = sketchPath(".pixel_density_pref.txt");
    saveStrings(path, new String[] { str(max(1, pd)) });
  }

  int particlesFromSlider() {
    int idx = constrain(round(countSlider.value), 0, maxPowIndex);
    return 2 << idx;
  }

  float energyFromSlider() {
    int idx = constrain(round(energySlider.value), 0, maxEnergyPowIndex);
    return 1 << idx;
  }

  void applySliderChanges() {
    int newN = particlesFromSlider();
    if (newN != n_balls) {
      n_balls = newN;
      resetSimulation();
    }
    float newUe = energyFromSlider();
    if (abs(newUe - energyMult) > 0.0001) {
      float ratio = newUe / energyMult;
      for (int i = 0; i < balls.length; i++) {
        balls[i].velocity.mult(ratio);
      }
      energyMult = newUe;
    }
    int newEvery = samplesFromSlider();
    if (newEvery != pressureEvery) {
      pressureEvery = newEvery;
      k = 0;
      counter = 0.0;
    }
    pistonOscFreq = waveFreqSlider.value;
    pistonOscAmp = waveAmpSlider.value;
    acousticDiss = wallDissSlider.value;
    topWallDiss = topWallDissSlider.value;
    adiabaticCompressStep = adiaSpeedSlider.value;
  }

  int samplesFromSlider() {
    int idx = constrain(round(pressureSlider.value), 0, maxSamplesPowIndex);
    return 2 << idx;
  }

  void drawCountSlider() {
    // Dibuixa l'slider però mostrant el valor discret (potències de 2)
    countSlider.drawNoLabel();
    int val = particlesFromSlider();
    fill(220);
    textAlign(LEFT, BOTTOM);
    textSize(14);
    text("Partícules:  " + val, countSlider.x, countSlider.y - 4);
  }

  void drawEnergySlider() {
    // Dibuixa l'slider però mostrant el valor discret (potències de 2)
    if (adiabaticMode) {
      energySlider.drawNoLabelDisabled();
    } else {
      energySlider.drawNoLabel();
    }
    float val = energyFromSlider();
    fill(adiabaticMode ? 170 : 220);
    textAlign(LEFT, BOTTOM);
    textSize(14);
    text("⟨v²⟩ [ua]: " + nf(val, 0, 0), energySlider.x, energySlider.y - 4);
  }

  void drawPressureSlider() {
    pressureSlider.drawNoLabel();
    int val = samplesFromSlider();
    fill(220);
    textAlign(LEFT, BOTTOM);
    textSize(14);
    text("Mostres pressió:  " + val, pressureSlider.x, pressureSlider.y - 4);
  }

  void drawAdiaSpeedSlider() {
    if (adiabaticMode) {
      adiaSpeedSlider.drawNoLabel();
    } else {
      adiaSpeedSlider.drawNoLabelDisabled();
    }
    fill(adiabaticMode ? 220 : 170);
    textAlign(LEFT, BOTTOM);
    textSize(13);
    text("Vel. pistó adiab. [px/f]: " + nf(adiaSpeedSlider.value, 0, 1), adiaSpeedSlider.x, adiaSpeedSlider.y - 3);
  }

  void drawWaveFreqSlider() {
    if (pistonOscOn) {
      waveFreqSlider.drawNoLabel();
    } else {
      waveFreqSlider.drawNoLabelDisabled();
    }
    fill(pistonOscOn ? 220 : 170);
    textAlign(LEFT, BOTTOM);
    textSize(13);
    text("Freqüència pistó [Hz]: " + nf(waveFreqSlider.value, 0, 3), waveFreqSlider.x, waveFreqSlider.y - 3);
  }

  void drawWallDissSlider() {
    if (pistonOscOn) {
      wallDissSlider.drawNoLabel();
    } else {
      wallDissSlider.drawNoLabelDisabled();
    }
    fill(pistonOscOn ? 220 : 170);
    textAlign(LEFT, BOTTOM);
    textSize(13);
    text("Dissipació parets: " + nf(wallDissSlider.value, 0, 3), wallDissSlider.x, wallDissSlider.y - 3);
  }

  void drawTopWallDissSlider() {
    if (pistonOscOn) {
      topWallDissSlider.drawNoLabel();
    } else {
      topWallDissSlider.drawNoLabelDisabled();
    }
    fill(pistonOscOn ? 220 : 170);
    textAlign(LEFT, BOTTOM);
    textSize(13);
    text("Dissipació paret superior: " + nf(topWallDissSlider.value, 0, 3), topWallDissSlider.x, topWallDissSlider.y - 3);
  }

  void drawGauges() {
    float gaugeY = sliderY + sliderGap * 2 + 185;
    float r = 58;
    float cx1 = panelX + panelW * 0.19;
    float cy1 = gaugeY;
    float cx2 = panelX + panelW * 0.50;
    float cy2 = gaugeY;
    float cx3 = panelX + panelW * 0.81;
    float cy3 = gaugeY;

    float vNow = w * h;
    drawGauge(cx1, cy1, r, "Pressió [ua]", pressureDisplay, 0, 10000.0, true, 1.0, "", true);
    drawPressureBand(cx1, cy1, r);
    drawGauge(cx2, cy2, r, "Volum [pix^2]", vNow, 0, 1600000.0, true, 1000.0, "x1000", false);
    drawGauge(cx3, cy3, r, "T [1/kB]", fitSigma, 0, 50.0, true, 1.0, "", false);
    drawSigmaBand(cx3, cy3, r);
    if (vNow > 1600000.0) {
      float a = radians(430); // just past the 1600 mark
      float px = cx2 + cos(a) * (r + 14);
      float py = cy2 + sin(a) * (r + 14);
      stroke(20);
      strokeWeight(1.2);
      fill(230, 60, 60);
      ellipse(px, py, 10, 10);
      noStroke();
    }
    if (fitSigma > 50.0) {
      float a = radians(430); // just past the max T mark
      float px = cx3 + cos(a) * (r + 14);
      float py = cy3 + sin(a) * (r + 14);
      stroke(20);
      strokeWeight(1.2);
      fill(230, 60, 60);
      ellipse(px, py, 10, 10);
      noStroke();
    }
  }

  void drawPressureBand(float cx, float cy, float r) {
    if (!pressureRangeInit) return;
    float start = radians(120);
    float end = radians(420);
    float vmax = 10000.0;
    float t1 = constrain(log(1.0 + max(0.0, pressureMin)) / log(1.0 + vmax), 0, 1);
    float t2 = constrain(log(1.0 + max(0.0, pressureMax)) / log(1.0 + vmax), 0, 1);
    float a1 = lerp(start, end, t1);
    float a2 = lerp(start, end, t2);
    float aMin = min(a1, a2);
    float aMax = max(a1, a2);
    float minSpan = radians(3);
    if (aMax - aMin < minSpan) {
      float mid = (aMin + aMax) * 0.5;
      aMin = mid - minSpan * 0.5;
      aMax = mid + minSpan * 0.5;
    }
    noStroke();
    fill(240, 220, 90, 90);
    beginShape();
    vertex(cx, cy);
    int steps = 24;
    for (int i = 0; i <= steps; i++) {
      float a = lerp(aMin, aMax, i / (float)steps);
      vertex(cx + cos(a) * r, cy + sin(a) * r);
    }
    endShape(CLOSE);
    strokeWeight(1);
  }

  void drawSigmaBand(float cx, float cy, float r) {
    if (!sigmaRangeInit) return;
    float start = radians(120);
    float end = radians(420);
    float vmax = 50.0;
    float t1 = constrain(max(0.0, sigmaMin) / max(0.0001, vmax), 0, 1);
    float t2 = constrain(max(0.0, sigmaMax) / max(0.0001, vmax), 0, 1);
    float a1 = lerp(start, end, t1);
    float a2 = lerp(start, end, t2);
    float aMin = min(a1, a2);
    float aMax = max(a1, a2);
    float minSpan = radians(3);
    if (aMax - aMin < minSpan) {
      float mid = (aMin + aMax) * 0.5;
      aMin = mid - minSpan * 0.5;
      aMax = mid + minSpan * 0.5;
    }
    noStroke();
    fill(230, 80, 80, 90);
    beginShape();
    vertex(cx, cy);
    int steps = 24;
    for (int i = 0; i <= steps; i++) {
      float a = lerp(aMin, aMax, i / (float)steps);
      vertex(cx + cos(a) * r, cy + sin(a) * r);
    }
    endShape(CLOSE);
    strokeWeight(1);
  }

  void updateHistogram() {
    for (int i = 0; i < histBins; i++) hist[i] = 0;
    float maxV = 0.0;
    float sumV2 = 0.0;
    float sumV = 0.0;
    for (int i = 0; i < balls.length; i++) {
      float v = sqrt(sq(balls[i].velocity.x) + sq(balls[i].velocity.y));
      if (v > maxV) maxV = v;
      sumV2 += v * v;
      sumV += v;
    }
    if (maxV < 0.0001) maxV = 0.0001;
    histMaxSpeed = maxV;
    float meanV2 = sumV2 / max(1.0, (float)balls.length);
    fitSigma = sqrt(meanV2 / 2.0);
    fitMeanV = sumV / max(1.0, (float)balls.length);
    for (int i = 0; i < balls.length; i++) {
      float v = sqrt(sq(balls[i].velocity.x) + sq(balls[i].velocity.y));
      int b = int(map(v, 0, histMaxSpeed, 0, histBins - 1));
      b = constrain(b, 0, histBins - 1);
      hist[b] += 1;
    }
    // Refina sigma ajustant la corba teòrica als bins de l'histograma.
    fitSigma = fitSigmaFromHistogram(fitSigma);
    if (!sigmaRangeInit) {
      sigmaMin = fitSigma;
      sigmaMax = fitSigma;
      sigmaRangeInit = true;
    } else {
      // Encara més memòria: decaïment extremadament lent.
      float decay = max(0.00005, (sigmaMax - sigmaMin) * 0.001);
      sigmaMin = min(fitSigma, sigmaMin + decay);
      sigmaMax = max(fitSigma, sigmaMax - decay);
    }
  }

  float fitSigmaFromHistogram(float initialSigma) {
    float dv = histMaxSpeed / (float)histBins;
    if (dv <= 0.000001) return initialSigma;

    float sMin = max(dv * 0.25, initialSigma * 0.2);
    float sMax = max(dv * 2.0, initialSigma * 3.0);
    float bestS = initialSigma;
    float bestE = histogramFitError(initialSigma, dv);

    // Cerca gruixuda en espai logarítmic.
    int coarseSteps = 80;
    float logMin = log(sMin);
    float logMax = log(sMax);
    for (int i = 0; i < coarseSteps; i++) {
      float t = i / (float)(coarseSteps - 1);
      float s = exp(lerp(logMin, logMax, t));
      float e = histogramFitError(s, dv);
      if (e < bestE) {
        bestE = e;
        bestS = s;
      }
    }

    // Refinament local al voltant del millor valor.
    float left = max(dv * 0.25, bestS * 0.7);
    float right = bestS * 1.3;
    int fineSteps = 60;
    for (int i = 0; i < fineSteps; i++) {
      float t = i / (float)(fineSteps - 1);
      float s = lerp(left, right, t);
      float e = histogramFitError(s, dv);
      if (e < bestE) {
        bestE = e;
        bestS = s;
      }
    }
    return bestS;
  }

  float histogramFitError(float sigma, float dv) {
    if (sigma <= 0.000001) return 1e30;
    float err = 0.0;
    for (int i = 0; i < histBins; i++) {
      float v = (i + 0.5) * dv;
      float f = (v / (sigma * sigma)) * exp(-(v * v) / (2.0 * sigma * sigma));
      float expected = f * balls.length * dv;
      float d = hist[i] - expected;
      err += d * d;
    }
    return err;
  }

  void drawHistogram() {
    float hy = sliderY + sliderGap * 2 + 170 + 200;
    float hw = (panelW - 80) * 0.75;
    float hx = panelX + 40 + ((panelW - 80) - hw) * 0.5;
    float hh = 140;

    noStroke();
    fill(30);
    rect(hx, hy, hw, hh, 6);

    fill(220);
    textAlign(LEFT, TOP);
    textSize(14);
    text("Histograma velocitats", hx, hy - 18);

    stroke(180);
    strokeWeight(1);
    line(hx, hy + hh, hx + hw, hy + hh); // eix X
    line(hx, hy, hx, hy + hh); // eix Y

    int maxCount = 1;
    for (int i = 0; i < histBins; i++) {
      if (hist[i] > maxCount) maxCount = hist[i];
    }
    float barW = hw / (float)histBins;
    for (int i = 0; i < histBins; i++) {
      float bh = map(hist[i], 0, maxCount, 0, hh - 20);
      float bx = hx + i * barW;
      float by = hy + hh - bh;
      fill(230, 170, 40);
      rect(bx + 1, by, barW - 2, bh);
    }

    // Maxwell-Boltzmann 2D fit curve (scaled to histogram)
    if (fitSigma > 0.0001) {
      float dv = histMaxSpeed / (float)histBins;
      stroke(120, 180, 240);
      strokeWeight(2);
      noFill();
      beginShape();
      for (int i = 0; i <= histBins; i++) {
        float v = (i + 0.5) * dv;
        float f = (v / (fitSigma*fitSigma)) * exp(- (v*v) / (2.0 * fitSigma*fitSigma));
        float expected = f * balls.length * dv;
        float bh = map(expected, 0, maxCount, 0, hh - 20);
        float x = hx + i * (hw / (float)histBins);
        float y = hy + hh - bh;
        vertex(x, y);
      }
      endShape();
    }

    fill(180);
    textSize(10);
    textAlign(LEFT, BOTTOM);
    text("0", hx, hy + hh + 14);
    textAlign(CENTER, BOTTOM);
    text(nf(histMaxSpeed * 0.5, 0, 1), hx + hw * 0.5, hy + hh + 14);
    textAlign(RIGHT, BOTTOM);
    text(nf(histMaxSpeed, 0, 1), hx + hw, hy + hh + 14);

    int yTop = maxCount;
    textAlign(RIGHT, CENTER);
    text("0", hx - 6, hy + hh);
    text(str(yTop), hx - 6, hy + 6);

    // Labels d'eixos
    fill(160);
    textAlign(CENTER, TOP);
    text("v", hx + hw * 0.5, hy + hh + 20);
    pushMatrix();
    translate(hx - 26, hy + hh * 0.5);
    rotate(-HALF_PI);
    textAlign(CENTER, CENTER);
    text("N(v)", 0, 0);
    popMatrix();

    fill(200);
    textSize(13);
    textAlign(LEFT, TOP);
    float labelRight = hx + hw;
    float line1Y = hy - 4;
    float line2Y = hy + 12;
    float line3Y = hy + 28;
    String line1 = "Ajust M-B (2D):";
    String kbtValue = "T=" + nf(fitSigma, 0, 2);
    String line3 = "<v>=" + nf(fitMeanV, 0, 2) + " ";

    textSize(13);
    float wLine1 = textWidth(line1);
    float wK = textWidth("k");
    textSize(9);
    float wB = textWidth("B");
    textSize(13);
    float wT = textWidth(kbtValue);
    float wLine2 = wK + wB + wT;
    float wLine3 = textWidth(line3);
    float maxW = max(wLine1, max(wLine2, wLine3));
    float xStart = labelRight - maxW;

    textSize(13);
    text(line1, xStart, line1Y);
    text("k", xStart, line2Y);
    textSize(9);
    text("B", xStart + wK, line2Y + 4);
    textSize(13);
    text(kbtValue, xStart + wK + wB, line2Y);
    text(line3, xStart, line3Y);
  }

  void drawHistButtons() {
    float by = sliderY + sliderGap * 2 + 170 + 200 + 180;
    float bx = panelX + 40;
    float bw = 60;
    float bh = 24;
    float gap = 8;

    drawMiniButtonIcon(bx, by, bw, bh, "Cap", histEvery == 0, ICON_PAUSE);
    drawMiniButtonIcon(bx + (bw + gap), by, bw, bh, "1", histEvery == 1, ICON_PLAY);
    drawMiniButtonIcon(bx + (bw + gap) * 2, by, bw, bh, "10", histEvery == 10, ICON_PLAY);
    drawMiniButtonIcon(bx + (bw + gap) * 3, by, bw, bh, "100", histEvery == 100, ICON_PLAY);
    drawMiniButtonIcon(bx + (bw + gap) * 4, by, bw, bh, "1000", histEvery == 1000, ICON_PLAY);
  }

  void drawMiniButton(float x, float y, float w_, float h_, String label, boolean active) {
    if (active) {
      fill(230, 170, 40);
    } else {
      fill(200);
    }
    rect(x, y, w_, h_, 6);
    fill(20);
    textAlign(CENTER, CENTER);
    textSize(13);
    text(label, x + w_/2.0, y + h_/2.0);
  }

  void drawMiniButtonState(float x, float y, float w_, float h_, String label, boolean active, boolean enabled) {
    if (!enabled) {
      fill(215);
    } else if (active) {
      fill(230, 170, 40);
    } else {
      fill(200);
    }
    rect(x, y, w_, h_, 6);
    fill(enabled ? 20 : 130);
    textAlign(CENTER, CENTER);
    textSize(16);
    text(label, x + w_/2.0, y + h_/2.0);
  }

  void drawMiniButtonIcon(float x, float y, float w_, float h_, String label, boolean active, int icon) {
    if (active) {
      fill(230, 170, 40);
    } else {
      fill(200);
    }
    rect(x, y, w_, h_, 6);
    float cy = y + h_/2.0;
    float iconGap = 6;
    float iconSize = 8;
    float textW = textWidth(label);
    float totalW = iconSize + iconGap + textW;
    float startX = x + (w_ - totalW) * 0.5;
    float cx = startX + iconSize * 0.5;
    drawIcon(icon, cx, cy, iconSize);
    fill(20);
    textAlign(LEFT, CENTER);
    textSize(13);
    text(label, startX + iconSize + iconGap, cy);
  }

  final int ICON_RESET = 0;
  final int ICON_PAUSE = 1;
  final int ICON_PLAY = 2;
  final int ICON_SAVE = 3;
  final int ICON_SHOT = 4;

  void drawIcon(int type, float cx, float cy, float s) {
    stroke(20);
    strokeWeight(2);
    if (type == ICON_PLAY) {
      noStroke();
      fill(20);
      triangle(cx - s*0.4, cy - s*0.5, cx - s*0.4, cy + s*0.5, cx + s*0.5, cy);
    } else if (type == ICON_PAUSE) {
      noStroke();
      fill(20);
      rect(cx - s*0.5, cy - s*0.5, s*0.3, s);
      rect(cx + s*0.2, cy - s*0.5, s*0.3, s);
    } else if (type == ICON_RESET) {
      noFill();
      arc(cx, cy, s*1.2, s*1.2, radians(30), radians(300));
      noStroke();
      fill(20);
      float ax = cx + cos(radians(30)) * (s*0.6);
      float ay = cy + sin(radians(30)) * (s*0.6);
      triangle(ax, ay, ax - 4, ay - 2, ax - 1, ay + 4);
    } else if (type == ICON_SAVE) {
      noStroke();
      fill(20);
      rect(cx - s*0.6, cy - s*0.6, s*1.2, s*1.2, 2);
      fill(200);
      rect(cx - s*0.4, cy - s*0.5, s*0.8, s*0.35);
      fill(20);
      rect(cx - s*0.3, cy + s*0.05, s*0.6, s*0.35);
    } else if (type == ICON_SHOT) {
      noStroke();
      fill(20);
      rect(cx - s*0.7, cy - s*0.45, s*1.4, s*0.9, 2);
      rect(cx - s*0.35, cy - s*0.7, s*0.7, s*0.25, 2);
      fill(200);
      ellipse(cx, cy, s*0.6, s*0.6);
      fill(20);
      ellipse(cx, cy, s*0.3, s*0.3);
    }
  }

  void drawGauge(float cx, float cy, float r, String label, float value, float vmin, float vmax, boolean showNumbers, float scaleDiv, String suffix, boolean logScale) {
    boolean isTempGauge = label.equals("T [1/kB]");
    float start = radians(120);
    float end = radians(420);
    float t;
    if (logScale) {
      float lv = log(1.0 + max(0.0, value));
      float lmax = log(1.0 + max(1.0, vmax));
      t = constrain(lv / lmax, 0, 1);
    } else {
      t = constrain((value - vmin) / max(0.0001, (vmax - vmin)), 0, 1);
    }
    float ang = lerp(start, end, t);

    stroke(80);
    strokeWeight(10);
    noFill();
    arc(cx, cy, r*2, r*2, start, end);

    stroke(200);
    strokeWeight(2);
    if (logScale) {
      if (isTempGauge) {
        // Més ticks i inclou el 0 explícit a l'escala de temperatura.
        int nTicks = 10;
        for (int i = 0; i <= nTicks; i++) {
          float tt = i / (float)nTicks;
          float a = lerp(start, end, tt);
          float inner = (i % 2 == 0) ? (r - 7) : (r - 5);
          float x1 = cx + cos(a) * inner;
          float y1 = cy + sin(a) * inner;
          float x2 = cx + cos(a) * (r + 4);
          float y2 = cy + sin(a) * (r + 4);
          line(x1, y1, x2, y2);
          if (showNumbers && (i % 2 == 0)) {
            float tv = lerp(vmin, vmax, tt) / scaleDiv;
            float tx = cx + cos(a) * (r + 16);
            float ty = cy + sin(a) * (r + 16);
            fill(220);
            textAlign(CENTER, CENTER);
            textSize(11);
            text(str(round(tv)), tx, ty);
          }
        }
      } else {
        // ticks logarítmics amb valors rodons (1,2,5 per dècada)
        float maxV = max(1.0, vmax);
        for (int p = 0; p <= 6; p++) {
          float base = pow(10, p);
          float[] mult = {1, 2, 5};
          for (int mi = 0; mi < mult.length; mi++) {
            float tv = mult[mi] * base;
            if (tv > maxV) continue;
            float tt = log(1.0 + tv) / log(1.0 + maxV);
            float a = lerp(start, end, tt);
            float x1 = cx + cos(a) * (r - 6);
            float y1 = cy + sin(a) * (r - 6);
            float x2 = cx + cos(a) * (r + 4);
            float y2 = cy + sin(a) * (r + 4);
            line(x1, y1, x2, y2);
            if (showNumbers) {
              float tx = cx + cos(a) * (r + 16);
              float ty = cy + sin(a) * (r + 16);
              fill(220);
              textAlign(CENTER, CENTER);
              textSize(11);
              text(str(round(tv / scaleDiv)), tx, ty);
            }
          }
        }
      }
    } else {
      for (int i = 0; i <= 10; i++) {
        float a = lerp(start, end, i/10.0);
        float x1 = cx + cos(a) * (r - 6);
        float y1 = cy + sin(a) * (r - 6);
        float x2 = cx + cos(a) * (r + 4);
        float y2 = cy + sin(a) * (r + 4);
        line(x1, y1, x2, y2);
        if (showNumbers && (i % 2 == 0)) {
          float tv = lerp(vmin, vmax, i/10.0) / scaleDiv;
          int tvi = round(tv);
          float tx = cx + cos(a) * (r + 16);
          float ty = cy + sin(a) * (r + 16);
          if (suffix.equals("x1000") && (tvi == 1280 || tvi == 1600)) {
            tx += 10;
          }
          fill(220);
          textAlign(CENTER, CENTER);
          textSize(12);
          text(str(tvi), tx, ty);
        }
      }
    }

    stroke(240, 220, 90);
    strokeWeight(3);
    line(cx, cy, cx + cos(ang) * (r - 10), cy + sin(ang) * (r - 10));
    noStroke();
    fill(240, 220, 90);
    ellipse(cx, cy, 8, 8);

    fill(220);
    textAlign(CENTER, TOP);
    textSize(14);
    text(label + (suffix.length() > 0 ? " (" + suffix + ")" : ""), cx, cy + r + 20);
    textFont(gaugeNumberFont);
    fill(120, 180, 240);
    textSize(26);
    if (label.equals("T [1/kB]")) {
      text(nf(value / scaleDiv, 0, 1), cx, cy + r + 48);
    } else {
      int vshow = round(value / scaleDiv);
      text(str(vshow), cx, cy + r + 48);
    }
    textFont(uiFont);
    fill(220);
  }

  class Slider {
    float x, y, w, h;
    float minV, maxV;
    float value;
    String label;
    int decimals;
    boolean dragging = false;
    boolean snap = false;

    Slider(float x, float y, float w, float h, float minV, float maxV, float value, String label, int decimals, boolean snap) {
      this.x=x; this.y=y; this.w=w; this.h=h;
      this.minV=minV; this.maxV=maxV; this.value=constrain(value, minV, maxV);
      this.label=label;
      this.decimals = decimals;
      this.snap = snap;
    }

    void draw() {
      // label + valor
      fill(220);
      textAlign(LEFT, BOTTOM);
      textSize(14);
      text(label + "  " + nf(value, 0, decimals), x, y - 4);

      // rail base
      float cy = y + h * 0.5;
      stroke(120);
      strokeWeight(3);
      line(x, cy, x + w, cy);

      // progress rail
      float t = map(value, minV, maxV, 0, 1);
      float kx = x + t * w;
      stroke(230, 170, 40);
      strokeWeight(3);
      line(x, cy, kx, cy);

      // knob
      noStroke();
      fill(240);
      ellipse(kx, cy, h*1.6, h*1.6);
      stroke(230, 170, 40);
      strokeWeight(1.5);
      noFill();
      ellipse(kx, cy, h*1.6, h*1.6);

      // small inner dot
      noStroke();
      fill(230, 170, 40);
      ellipse(kx, cy, h*0.45, h*0.45);

      // caixa invisible per facilitar clicar
      noFill();
      stroke(0, 0);
      rect(x, y, w, h);
    }

    void drawNoLabel() {
      float cy = y + h * 0.5;
      stroke(120);
      strokeWeight(3);
      line(x, cy, x + w, cy);

      float t = map(value, minV, maxV, 0, 1);
      float kx = x + t * w;
      stroke(230, 170, 40);
      strokeWeight(3);
      line(x, cy, kx, cy);

      noStroke();
      fill(240);
      ellipse(kx, cy, h*1.6, h*1.6);
      stroke(230, 170, 40);
      strokeWeight(1.5);
      noFill();
      ellipse(kx, cy, h*1.6, h*1.6);

      noStroke();
      fill(230, 170, 40);
      ellipse(kx, cy, h*0.45, h*0.45);

      noFill();
      stroke(0, 0);
      rect(x, y, w, h);
    }

    void drawNoLabelDisabled() {
      float cy = y + h * 0.5;
      stroke(165);
      strokeWeight(3);
      line(x, cy, x + w, cy);

      float t = map(value, minV, maxV, 0, 1);
      float kx = x + t * w;
      stroke(210);
      strokeWeight(3);
      line(x, cy, kx, cy);

      noStroke();
      fill(230);
      ellipse(kx, cy, h*1.6, h*1.6);
      stroke(210);
      strokeWeight(1.5);
      noFill();
      ellipse(kx, cy, h*1.6, h*1.6);

      noStroke();
      fill(210);
      ellipse(kx, cy, h*0.45, h*0.45);

      noFill();
      stroke(0, 0);
      rect(x, y, w, h);
    }

    void mousePressed(float mx, float my) {
      if (mx >= x && mx <= x+w && my >= y-8 && my <= y+h+8) {
        dragging = true;
        setFromMouse(mx);
      }
    }

    void mouseDragged(float mx, float my) {
      if (dragging) setFromMouse(mx);
    }

    void mouseReleased() {
      dragging = false;
    }

    void setFromMouse(float mx) {
      float t = constrain((mx - x) / w, 0, 1);
      value = lerp(minV, maxV, t);
      if (snap) {
        value = round(value);
      }
    }
  }

  class TwoPosSwitch {
    float x, y, w, h;
    boolean lowMode = false;
    String leftLabel;
    String rightLabel;

    TwoPosSwitch(float x, float y, float w, float h, boolean lowMode, String leftLabel, String rightLabel) {
      this.x = x;
      this.y = y;
      this.w = w;
      this.h = h;
      this.lowMode = lowMode;
      this.leftLabel = leftLabel;
      this.rightLabel = rightLabel;
    }

    void draw() {
      float half = w * 0.5;
      float r = h * 0.5;

      // Ombra subtil
      noStroke();
      fill(0, 40);
      rect(x + 1, y + 1, w, h, r);

      // Base
      fill(55);
      rect(x, y, w, h, r);

      // Segment actiu
      float selX = lowMode ? x + half : x;
      fill(240, 185, 70);
      rect(selX + 1, y + 1, half - 2, h - 2, r - 1);

      // Separador i contorn
      stroke(120);
      strokeWeight(1);
      line(x + half, y + 2, x + half, y + h - 2);
      noFill();
      stroke(150);
      rect(x, y, w, h, r);

      // Indicador visual del costat seleccionat
      noStroke();
      fill(250);
      float dotX = lowMode ? (x + half + 8) : (x + 8);
      ellipse(dotX, y + h * 0.5, 4, 4);

      textAlign(CENTER, CENTER);
      textSize(10);
      fill(lowMode ? 210 : 15);
      text(leftLabel, x + half * 0.5, y + h * 0.52);
      fill(lowMode ? 15 : 210);
      text(rightLabel, x + half * 1.5, y + h * 0.52);
    }

    boolean hit(float mx, float my) {
      return (mx >= x && mx <= x + w && my >= y && my <= y + h);
    }

    void mousePressed(float mx, float my) {
      if (!hit(mx, my)) return;
      float half = x + w * 0.5;
      lowMode = (mx >= half);
    }
  }
  
    
  
/* Bloc de variables locals i config.
----------------------------------------------------------------
n_balls :: nombre de partícules del sistema
w,h :: dimensions del tauler
----------------------------------------------------------------
**/
  
  int k = 0;
  float counter = 0.0;
  
  int n_balls = 64;
  int minBalls = 2;
  int maxBalls = 8192;
  int maxPowIndex = 12; // 2 * 2^12 = 8192
  int maxEnergyPowIndex = 6; // 2^6 = 64
  int minPressureEvery = 2;
  int maxPressureEvery = 1024;
  int pressureEvery = 8;
  int maxSamplesPowIndex = 9; // 2..1024
  boolean paused = false;
  boolean draggingPiston = false;
  boolean adiabaticMode = false;
  int adiabaticDirection = 0; // -1 comprimeix, +1 expandeix, 0 aturat
  boolean adiaButtonHeld = false;
  float pressureDisplay = 0.0;
  float maxPressure = 10.0;
  float maxVolume = 1000.0;
  float pressureMin = 0.0;
  float pressureMax = 0.0;
  boolean pressureRangeInit = false;
  StringList logLines = new StringList();
  
  Ball[] balls = new Ball[n_balls];
  float[] velocity_list = new float[n_balls];
  PrintWriter output;
  
  int w = 500; //dim. vertical
  int h = 1100; //dim. horitzontal  
  int boardW = 920;
  int boardH = 920;
  int windowH = 920;
  int pistonMaxW = 1800;
  int pistonMinW = 40;
  float adiabaticCompressStep = 1.0;
  int pistonStart = 598;
  int panelW = 620;
  int panelX = boardW;
  float buttonW = 96;
  float buttonH = 32;
  float buttonGap = 8;
  float resetX = panelX + 30;
  float resetY = 30;
  float stopX = resetX + buttonW + buttonGap;
  float stopY = 30;
  float saveX = resetX + (buttonW + buttonGap) * 2;
  float saveY = 30;
  float shotX = resetX + (buttonW + buttonGap) * 3;
  float shotY = 30;
  float adiaUpX = panelX + 30 + 180 + 10;
  float adiaDownX = adiaUpX + 34 + 8;
  float adiaStepY = resetY + buttonH + 10;
  float adiaStepW = 34;
  float adiaStepH = 24;
  float energyMult = 8.0;

  float sliderX = panelX + 30;
  float sliderY = 170;
  float sliderW = (panelW - 90) * 0.5;
  float sliderH = 8;
  float sliderGap = 58;
  Slider countSlider;
  Slider energySlider;
  Slider pressureSlider;
  Slider adiaSpeedSlider;
  Slider waveFreqSlider;
  Slider waveAmpSlider;
  Slider wallDissSlider;
  Slider topWallDissSlider;
  TwoPosSwitch resSwitch;
  TwoPosSwitch adiaSwitch;
  TwoPosSwitch waveSwitch;
  PFont gaugeNumberFont;
  PFont uiFont;
  boolean lowRes = false;
  int configuredPixelDensity = 1;
  float pistonVY = 0.0;
  float prevPistonW = 0.0;
  
   
void settings() {
  configuredPixelDensity = loadPixelDensityPreference();
  size(boardW + panelW, windowH);
  pixelDensity(configuredPixelDensity);
}

void setup() {
  // Fixa les dimensions del recinte al tamany del tauler de col·lisions
  w = pistonStart; //dim. vertical (posició inicial del pistó)
  h = boardW;  //dim. horitzontal
  pistonOscCenterW = w;
  monitorRectX = (boardW - monitorRectW) * 0.5;
  monitorRectY = (boardH - monitorRectH) * 0.5;
  
  countSlider = new Slider(sliderX, sliderY, sliderW, sliderH, 0, maxPowIndex, 3, "Partícules", 0, true);
  energySlider = new Slider(sliderX, sliderY + sliderGap, sliderW, sliderH, 0, maxEnergyPowIndex, 3, "Energia (x)", 0, true);
  pressureSlider = new Slider(sliderX, sliderY + sliderGap*2, sliderW, sliderH, 0, maxSamplesPowIndex, 2, "Pressió cada", 0, true);
  adiaSpeedSlider = new Slider(sliderX, sliderY + sliderGap * 3, sliderW, sliderH, 0.2, 10.0, adiabaticCompressStep, "Vel adiab", 1, false);
  waveFreqSlider = new Slider(panelX + 330, resetY + buttonH + 70, panelW - 370, sliderH, 0.002, 1.50, pistonOscFreq, "Freq", 3, false);
  waveAmpSlider = new Slider(panelX + 330, resetY + buttonH + 114, panelW - 370, sliderH, 0.0, 250.0, pistonOscAmp, "Amp", 1, false);
  wallDissSlider = new Slider(panelX + 330, resetY + buttonH + 158, panelW - 370, sliderH, 0.0, 1.0, acousticDiss, "Diss", 3, false);
  topWallDissSlider = new Slider(panelX + 330, resetY + buttonH + 202, panelW - 370, sliderH, 0.0, 1.0, topWallDiss, "DissSostre", 3, false);
  uiFont = createFont("DejaVu Sans", 12, true);
  gaugeNumberFont = createFont("DejaVu Sans Mono", 26, true);
  textFont(uiFont);
  lowRes = (configuredPixelDensity == 1);
  resSwitch = new TwoPosSwitch(panelX + 30, resetY + buttonH + 54, 74, 16, lowRes, "Alta", "Baixa");
  adiaSwitch = new TwoPosSwitch(panelX + 30, resetY + buttonH + 10, 180, 24, adiabaticMode, "Isotèrmic", "Adiabàtic");
  waveSwitch = new TwoPosSwitch(panelX + 330, resetY + buttonH + 10, 120, 24, pistonOscOn, "Off", "On");
  prevPistonW = w;
  resetSimulation();
  
  println("Pressió, Volum, Energia mitjana");
  
}
  
  
