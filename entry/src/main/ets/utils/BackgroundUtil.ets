import { wantAgent, common } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'BackgroundUtil';

/**
 * 后台长时任务工具：用于音频后台播放保活
 */
export class BackgroundUtil {
  /**
   * 启动后台长时任务（音频播放模式）
   */
  public static startContinuousTask(context?: common.UIAbilityContext): void {
    if (!context) {
      console.error(`${TAG}: context undefined`);
      return;
    }
    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: context.abilityInfo.bundleName,
          abilityName: context.abilityInfo.name,
        },
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    };

    wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: Object) => {
      try {
        backgroundTaskManager
          .startBackgroundRunning(context, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, wantAgentObj)
          .then(() => {
            console.info(`${TAG}: startBackgroundRunning succeeded`);
          })
          .catch((error: BusinessError) => {
            console.error(`${TAG}: startBackgroundRunning failed code=${error.code} msg=${error.message}`);
          });
      } catch (error) {
        const err = error as BusinessError;
        console.error(`${TAG}: startBackgroundRunning exception code=${err.code} msg=${err.message}`);
      }
    }).catch((error: BusinessError) => {
      console.error(`${TAG}: getWantAgent failed code=${error.code} msg=${error.message}`);
    });
  }

  /**
   * 停止后台长时任务
   */
  public static stopContinuousTask(context?: common.UIAbilityContext): void {
    if (!context) {
      return;
    }
    try {
      backgroundTaskManager
        .stopBackgroundRunning(context)
        .then(() => {
          console.info(`${TAG}: stopBackgroundRunning succeeded`);
        })
        .catch((error: BusinessError) => {
          console.error(`${TAG}: stopBackgroundRunning failed code=${error.code} msg=${error.message}`);
        });
    } catch (error) {
      const err = error as BusinessError;
      console.error(`${TAG}: stopBackgroundRunning exception code=${err.code} msg=${err.message}`);
    }
  }
}
