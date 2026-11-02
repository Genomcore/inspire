import { createContext, useContext } from 'react';

import { httpClient, type ApiClient } from './client';

export const ApiClientContext = createContext<ApiClient>(httpClient);
export const useApiClient = (): ApiClient => useContext(ApiClientContext);
