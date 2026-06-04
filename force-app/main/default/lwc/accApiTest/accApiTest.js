import { LightningElement } from 'lwc';
import { sendMessage } from 'lightning/accApi';

export default class AccApiTest extends LightningElement {
    test() {
        sendMessage();
    }
}
