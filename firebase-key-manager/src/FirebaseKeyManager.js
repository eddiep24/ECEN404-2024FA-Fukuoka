import React, { useState, useEffect } from 'react';
import {
  Box,
  Heading,
  VStack,
  HStack,
  Text,
  Input,
  Button,
  Alert,
  AlertIcon,
  AlertTitle,
  AlertDescription,
} from '@chakra-ui/react';
import { getDatabase, ref, get, set } from 'firebase/database';
import { app } from './firebase'; // Make sure this path is correct

const FirebaseKeyManager = () => {
  const [keys, setKeys] = useState({});
  const [editingKey, setEditingKey] = useState(null);
  const [editValue, setEditValue] = useState("");
  const [message, setMessage] = useState(null);

  useEffect(() => {
    const fetchKeys = async () => {
      const db = getDatabase(app);
      const dbRef = ref(db);
      try {
        const snapshot = await get(dbRef);
        if (snapshot.exists()) {
          setKeys(snapshot.val());
        } else {
          console.log("No data available");
        }
      } catch (error) {
        console.error("Error fetching data:", error);
        setMessage({ status: 'error', text: 'Failed to fetch keys. Please try again.' });
      }
    };
    fetchKeys();
  }, []);

  const handleEdit = (key, value) => {
    setEditingKey(key);
    setEditValue(value);
  };

  const handleSave = async () => {
    if (editingKey) {
      const db = getDatabase(app);
      const dbRef = ref(db, editingKey);
      try {
        await set(dbRef, editValue);
        setKeys(prevKeys => ({ ...prevKeys, [editingKey]: editValue }));
        setMessage({ status: 'success', text: 'Key updated successfully!' });
      } catch (error) {
        console.error("Error updating data:", error);
        setMessage({ status: 'error', text: 'Failed to update key. Please try again.' });
      }
      setEditingKey(null);
      setEditValue("");
    }
  };

  return (
    <Box maxWidth="md" margin="auto" p={4}>
      <Heading mb={4}>Firebase Key Manager</Heading>
      {message && (
        <Alert status={message.status} mb={4}>
          <AlertIcon />
          <AlertTitle mr={2}>{message.status === 'error' ? 'Error' : 'Success'}</AlertTitle>
          <AlertDescription>{message.text}</AlertDescription>
        </Alert>
      )}
      <VStack spacing={4} align="stretch">
        {Object.entries(keys).map(([key, value]) => (
          <HStack key={key} justify="space-between">
            <Text fontWeight="semibold">{key}:</Text>
            {editingKey === key ? (
              <Input
                value={editValue}
                onChange={(e) => setEditValue(e.target.value)}
                width="auto"
                flexGrow={1}
              />
            ) : (
              <Text flexGrow={1}>{typeof value === 'object' ? JSON.stringify(value) : value}</Text>
            )}
            {editingKey === key ? (
              <Button onClick={handleSave} colorScheme="blue">Save</Button>
            ) : (
              <Button onClick={() => handleEdit(key, value)}>Edit</Button>
            )}
          </HStack>
        ))}
      </VStack>
    </Box>
  );
};

export default FirebaseKeyManager;