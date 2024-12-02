import React from 'react';
import { ChakraProvider } from '@chakra-ui/react';
import FirebaseKeyManager from './FirebaseKeyManager';

function App() {
  return (
    <ChakraProvider>
      <FirebaseKeyManager />
    </ChakraProvider>
  );
}

export default App;