import { LightningElement, api } from 'lwc';

export default class ContactDetailsAgentCard extends LightningElement {
    // The Lightning Type Renderer will automatically pass the Apex Wrapper data into this property.
    @api value;
}