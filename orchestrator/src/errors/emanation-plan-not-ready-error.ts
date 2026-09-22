export class EmanationPlanNotReadyError extends Error {
  constructor() {
    super('emanation plan is not ready')
    this.name = 'EmanationPlanNotReadyError'
  }
}
