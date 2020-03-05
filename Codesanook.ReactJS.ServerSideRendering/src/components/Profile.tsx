import * as React from 'react';
interface IUser {
    firstName: string;
    lastName: string;
}

interface IProps {
    user: IUser;
}

const Profile = (props: IProps) => {

    return (
        <div>
            <ul>
                <li>First name: {props.user.firstName}</li>
                <li>Last name: {props.user.lastName}</li>
            </ul>
        </div>
    );
};

export default Profile;
