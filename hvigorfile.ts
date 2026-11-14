import { appPlugin } from '@hadss/hmrouter-plugin';
import { appTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [appPlugin({ ignoreModuleNames: [] })]
  /* Custom plugin to extend the functionality of Hvigor. */
}