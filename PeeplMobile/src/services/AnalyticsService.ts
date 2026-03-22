import { Mixpanel } from 'mixpanel-react-native';
import Config from 'react-native-config';

const analytics = new Mixpanel(Config.MIXPANEL_TOKEN || '', true);
void analytics.init();

export default analytics;
