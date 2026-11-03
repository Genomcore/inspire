export const paths = { home: '/', notFound: '*' } as const;
export const routeOf = (name: keyof typeof paths): string => paths[name];
