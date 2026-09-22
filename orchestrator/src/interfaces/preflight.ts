import type { Component } from '@/interfaces/component'
import type { RecipeStep } from '@/interfaces/recipe-step'

export interface Preflight {
  components: Component[]
  probe_profiles: string[]
  worktree_recipe: RecipeStep[]
}
