const closest = (target, selector) => target?.closest?.(selector)

export const ExerciseReorder = {
  mounted() {
    this.draggingExerciseId = null

    this.handleDragStart = (event) => {
      const handle = closest(event.target, '[data-role="exercise-drag-handle"]')

      if (!handle || !this.el.contains(handle)) {
        return
      }

      this.draggingExerciseId = handle.dataset.exerciseId

      if (event.dataTransfer) {
        event.dataTransfer.effectAllowed = 'move'
        event.dataTransfer.setData('text/plain', this.draggingExerciseId)
      }
    }

    this.handleDragOver = (event) => {
      const card = closest(event.target, '[data-role="exercise-card"]')

      if (!this.draggingExerciseId || !card || !this.el.contains(card)) {
        return
      }

      event.preventDefault()

      if (event.dataTransfer) {
        event.dataTransfer.dropEffect = 'move'
      }
    }

    this.handleDrop = (event) => {
      const card = closest(event.target, '[data-role="exercise-card"]')

      if (!this.draggingExerciseId || !card || !this.el.contains(card)) {
        this.draggingExerciseId = null
        return
      }

      event.preventDefault()

      const targetExerciseId = card.dataset.exerciseId

      if (targetExerciseId === this.draggingExerciseId) {
        this.draggingExerciseId = null
        return
      }

      const exerciseIds = this.reorderedExerciseIds(
        this.draggingExerciseId,
        targetExerciseId
      )

      if (exerciseIds.length > 0) {
        this.pushEvent('reorder_exercises', { exercise_ids: exerciseIds })
      }

      this.draggingExerciseId = null
    }

    this.handleDragEnd = () => {
      this.draggingExerciseId = null
    }

    this.el.addEventListener('dragstart', this.handleDragStart)
    this.el.addEventListener('dragover', this.handleDragOver)
    this.el.addEventListener('drop', this.handleDrop)
    this.el.addEventListener('dragend', this.handleDragEnd)
  },

  destroyed() {
    this.el.removeEventListener('dragstart', this.handleDragStart)
    this.el.removeEventListener('dragover', this.handleDragOver)
    this.el.removeEventListener('drop', this.handleDrop)
    this.el.removeEventListener('dragend', this.handleDragEnd)
  },

  reorderedExerciseIds(draggingExerciseId, targetExerciseId) {
    const exerciseIds = Array.from(
      this.el.querySelectorAll('[data-role="exercise-card"]')
    )
      .map((card) => card.dataset.exerciseId)
      .filter(Boolean)

    const draggingIndex = exerciseIds.indexOf(draggingExerciseId)
    const targetIndex = exerciseIds.indexOf(targetExerciseId)

    if (draggingIndex === -1 || targetIndex === -1) {
      return []
    }

    const [removedExerciseId] = exerciseIds.splice(draggingIndex, 1)
    exerciseIds.splice(targetIndex, 0, removedExerciseId)

    return exerciseIds
  },
}
