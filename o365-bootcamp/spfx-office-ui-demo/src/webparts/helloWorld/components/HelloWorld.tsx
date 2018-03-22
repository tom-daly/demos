import * as React from "react";
import styles from "./HelloWorld.module.scss";
import { IHelloWorldProps } from "./IHelloWorldProps";
import { escape } from "@microsoft/sp-lodash-subset";
import { DefaultButton } from "office-ui-fabric-react/lib/Button";
import { Dropdown, IDropdownProps } from "office-ui-fabric-react/lib/Dropdown";
import { TextField } from "office-ui-fabric-react/lib/TextField";
import { Icon } from "office-ui-fabric-react/lib/Icon";
import { Checkbox } from "office-ui-fabric-react/lib/Checkbox";
import { initializeIcons } from "@uifabric/icons";
import {
  DatePicker,
  DayOfWeek,
  IDatePickerStrings
} from "office-ui-fabric-react/lib/DatePicker";

initializeIcons();

export default class HelloWorld extends React.Component<IHelloWorldProps, {}> {
  public render(): React.ReactElement<IHelloWorldProps> {
    return (
      <div className={styles.helloWorld}>
        <div className="ms-bgColor-themeDarker">
          <h1 className="ms-font-xxl ms-fontColor-white" style={{ padding: 10 }}>Submit Time</h1>
        </div>

        <div className={styles.row}>
          <Dropdown
            placeHolder="Choose a project..."
            options={[
              { key: "Project A", text: "Project A" },
              { key: "Project B", text: "Project B" },
              { key: "Project C", text: "Project C" }
            ]}
          />
        </div>

        <div className={styles.row}>
          <DatePicker label="Date" placeholder="Select a date..." />
        </div>

        <div className={styles.row}>
          <TextField label="Hours" />
        </div>

        <div className={styles.row}>
          <TextField label="Minutes" />
        </div>

        <div className={styles.row}>
          <TextField label="Notes" multiline rows={4} />
        </div>

        <div className={styles.row}>
          <Checkbox label="Billable" checked />
        </div>

        <DefaultButton
          text="Submit"
          primary
          iconProps={{ iconName: "Accept" }}
          style={{ marginRight: 10 }}
        />
        <DefaultButton
          text="Cancel"
          primary
          iconProps={{ iconName: "Cancel" }}
        />
      </div>
    );
  }
}
