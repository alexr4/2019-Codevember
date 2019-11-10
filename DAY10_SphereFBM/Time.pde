static class Time {
  static public float deltaTime;
  static private float lastTime = 0;
  static public float startTime = 0;
  static public float time;
  static private boolean pause;

  static public float modTime, normTime, timeLoop;

  static private void update(PApplet context_, boolean pause_) {
    pause = pause_;
    float actualTime = context_.millis() - startTime;
    if(!pause) deltaTime = actualTime - lastTime;
    lastTime = actualTime;
    if(!pause) time += deltaTime;
  }

  static public void computeTimeAnimation(float time, float maxTime){
    modTime = floor(time % maxTime);
    normTime = modTime / maxTime;
    timeLoop = floor(time / maxTime);
  }

  static public void setStartTime(PApplet context_){
    startTime = context_.millis();
  }

  static public void resetTimeForExport(PApplet context_){
    startTime = context_.millis();
    modTime = 0;
    normTime = 0;
    timeLoop = 0;
  }
}
