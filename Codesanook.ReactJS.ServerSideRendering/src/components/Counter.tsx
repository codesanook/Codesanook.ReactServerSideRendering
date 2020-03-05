import * as React from 'react';
import { useState } from 'react';

interface IProps {
    defaultCounterValue: number;
}

const Counter = (props: IProps) => {

    const [counter, setCounter] = useState(props.defaultCounterValue);
    const handleButtonClick = () => {
        setCounter(counter + 1);
    };

    return (
        <div>
            <h1>{counter}</h1>
            <p>
                Click the button to increase a counter
            </p>
            <button onClick={handleButtonClick}>Increase counter</button>
        </div>
    );
};

export default Counter;
