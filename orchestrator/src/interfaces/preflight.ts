import type { Component } from './component'
import type { RecipeStep } from './recipe-step'

export interface Preflight {
  components: Component[]
  probe_profiles: string[]
  worktree_recipe: RecipeStep[]
}
