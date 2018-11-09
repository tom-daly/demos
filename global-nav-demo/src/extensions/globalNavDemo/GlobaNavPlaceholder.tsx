import * as React from "react";
import GlobalNav from "./GlobalNav/GlobalNav";

export default class GlobalNavPlaceholder extends React.Component<{}, {}> {
  public render(): JSX.Element {
    return (
        <div className='top-navigation'>
          <GlobalNav/>
        </div>
    );
  }
}
