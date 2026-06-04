import { LightningElement } from 'lwc';

export default class EmbedChatBot extends LightningElement {
    scriptLoaded = false;

    renderedCallback() {
        // Ensure the script loads only once
        if (this.scriptLoaded) return;

        const script = document.createElement('script');
        script.src = 'https://orgfarm-e5662b0e27-dev-ed.develop.my.site.com/ESWkbdeploymentservice1753966088851/assets/js/bootstrap.min.js';
        script.onload = () => {
            try {
                embeddedservice_bootstrap.settings.language = 'en_US';
                embeddedservice_bootstrap.init(
                    '00DgK000007r2MD',
                    'kbdeploymentservice',
                    'https://orgfarm-e5662b0e27-dev-ed.develop.my.site.com/ESWkbdeploymentservice1753966088851',
                    {
                        scrt2URL: 'https://orgfarm-e5662b0e27-dev-ed.develop.my.salesforce-scrt.com'
                    }
                );
            } catch (e) {
                console.error('Bot Init Error:', e);
            }
        };
        // Append to document body instead of the template if needed
        document.body.appendChild(script);

        this.scriptLoaded = true;
    }
}