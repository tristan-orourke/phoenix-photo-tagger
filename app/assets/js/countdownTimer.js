export default {
  mounted() {
    // Initialize timer start time and interval
    this.resetTimer()
    this.updateCountdown()
    // Use requestAnimationFrame for battery-efficient smooth animation
    this.animationFrameId = null
    this.startAnimation()
  },

  updated() {
    // When the timer resets (new photo or interval change), reset our client timer
    const newServerStartTime = parseInt(this.el.dataset.timerStartTime || Date.now())
    const newIntervalMs = parseInt(this.el.dataset.intervalMs || 5000)
    
    // If the server start time or interval changed, reset our client timer
    if (newServerStartTime !== this.serverStartTime || newIntervalMs !== this.intervalMs) {
      this.resetTimer()
      // Restart animation if it was stopped
      if (!this.animationFrameId) {
        this.startAnimation()
      }
    }
    
    this.updateCountdown()
  },

  destroyed() {
    this.stopAnimation()
  },

  startAnimation() {
    // Stop any existing animation
    this.stopAnimation()
    
    // Create animation loop using requestAnimationFrame
    const animate = () => {
      this.updateCountdown()
      
      // Continue animation if timer hasn't expired
      const now = Date.now()
      const elapsed = now - this.clientStartTime
      
      if (elapsed < this.intervalMs) {
        // Schedule next frame
        this.animationFrameId = requestAnimationFrame(animate)
      } else {
        // Timer expired, stop animation
        this.animationFrameId = null
      }
    }
    
    // Start the animation loop
    this.animationFrameId = requestAnimationFrame(animate)
  },

  stopAnimation() {
    if (this.animationFrameId !== null) {
      cancelAnimationFrame(this.animationFrameId)
      this.animationFrameId = null
    }
  },

  resetTimer() {
    // Reset timer using client-side time when the server indicates a reset
    this.clientStartTime = Date.now()
    this.serverStartTime = parseInt(this.el.dataset.timerStartTime || Date.now())
    this.intervalMs = parseInt(this.el.dataset.intervalMs || 5000)
  },

  updateCountdown() {
    const now = Date.now()
    const elapsed = now - this.clientStartTime
    const remaining = Math.max(0, this.intervalMs - elapsed)
    const secondsRemaining = Math.ceil(remaining / 1000)

    // Update the seconds display
    const secondsElement = this.el.querySelector("#countdown-seconds")
    if (secondsElement) {
      secondsElement.textContent = secondsRemaining
    }

    // Update the circular progress bar
    // Circle goes from full (offset = 0) to empty (offset = circumference) as time elapses
    const progressCircle = this.el.querySelector("#progress-circle")
    if (progressCircle) {
      const circumference = 2 * Math.PI * 16 // radius is 16
      const progress = Math.max(0, Math.min(1, elapsed / this.intervalMs))
      // Start at 0 (full circle) and go to circumference (empty circle)
      const offset = circumference * progress
      progressCircle.style.strokeDashoffset = offset
    }
  }
}

