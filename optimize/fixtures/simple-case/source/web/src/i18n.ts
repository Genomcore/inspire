export const text = {
  isAlive: {
    loading: {
      title: 'Checking the API…',
      detail: 'Waiting for the liveness endpoint to answer.',
    },
    alive: {
      title: 'API is alive',
      detail: (latencyMs: number, time: string) => `Answered in ${String(latencyMs)} ms at ${time}.`,
    },
    unavailable: {
      title: 'API is unavailable',
      noAnswer: (time: string) => `Nothing answered at ${time}. Start the API, then check again.`,
      wrongAnswer: (httpStatus: number, time: string) => `The endpoint answered HTTP ${String(httpStatus)} at ${time} instead of a liveness response.`,
    },
    endpoint: 'Endpoint',
    response: 'Response',
    failure: 'Failure',
    latency: 'Latency',
    checked: 'Checked',
    noResponse: 'No response',
    emptyBody: 'Empty body',
    pending: '…',
    checkAgain: 'Check again',
  },
  notFound: {
    label: 'Error 404',
    title: 'Page not found',
    nothingAt: 'There is nothing at',
    hint: 'The page may have moved, or the address has a typo.',
    home: 'Go to the home page',
  },
} as const;
