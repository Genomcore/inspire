import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';

import { text } from '../src/i18n';
import { NotFoundScreen } from '../src/screens/not-found-screen';

describe('NotFoundScreen', () => {
  it('names the missing path and links back home', () => {
    render(
      <MemoryRouter initialEntries={['/nowhere']}>
        <NotFoundScreen />
      </MemoryRouter>,
    );

    expect(screen.getByRole('heading', { name: text.notFound.title })).toBeInTheDocument();
    expect(screen.getByText('/nowhere')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: text.notFound.home })).toHaveAttribute('href', '/');
  });
});
