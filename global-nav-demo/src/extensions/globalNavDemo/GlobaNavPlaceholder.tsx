import * as React from "react";
import GlobalNav from "./GlobalNav/GlobalNav";

export default class GlobalNavPlaceholder extends React.Component<{}, {}> {
  public render(): JSX.Element {
    return (
        <div>
          <GlobalNav/>
        </div>
    );
  }
}
